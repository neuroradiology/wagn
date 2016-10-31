ACTS_PER_PAGE = Card.config.acts_per_page

def history?
  true
end

# must be called on all actions and before :set_name, :process_subcards and
# :validate_delete_children

def actionable?
  history? || respond_to?(:attachment)
end

def finalize_action?
  actionable? && current_action
end

def act_card?
  self == Card::ActManager.act_card
end

def rollback_request?
  history? && Env && Env.params["action_ids"] &&
    Env.params["action_ids"].class == Array
end

event :assign_action, :initialize,
      when: proc { |c| c.actionable? } do
  @current_act = director.need_act
  @current_action = Card::Action.create(
    card_act_id: @current_act.id,
    action_type: @action,
    draft: (Env.params["draft"] == "true")
  )
  if @supercard && @supercard != self
    @current_action.super_action = @supercard.current_action
  end
end

# stores changes in the changes table and assigns them to the current action
# removes the action if there are no changes
event :finalize_action, :finalize,
      when: proc { |c| c.finalize_action? } do
  @changed_fields = Card::Change::TRACKED_FIELDS.select do |f|
    changed_attributes.member? f
  end
  if @changed_fields.present?
    # FIXME: should be one bulk insert
    @changed_fields.each do |f|
      Card::Change.create field: f,
                          value: self[f],
                          card_action_id: @current_action.id
    end
    @current_action.update_attributes! card_id: id
  elsif @current_action.card_changes(true).empty?
    @current_action.delete
    @current_action = nil
  end
end

event :finalize_act,
      after: :finalize_action,
      when: proc { |c|  c.act_card? } do
  # removed subcards can leave behind actions without card id
  if @current_act.actions(true).empty?
    @current_act.delete
    @current_act = nil
  else
    @current_act.update_attributes! card_id: id
  end
end

event :rollback_actions, :prepare_to_validate,
      on: :update,
      when: proc { |c| c.rollback_request? } do
  revision = { subcards: {} }
  rollback_actions = Env.params["action_ids"].map do |a_id|
    Action.fetch(a_id) || nil
  end
  rollback_actions.each do |action|
    if action.card_id == id
      revision.merge!(revision(action))
    else
      revision[:subcards][action.card.name] = revision(action)
    end
  end
  Env.params["action_ids"] = nil
  binding.pry
  update_attributes! revision
  # rollback_actions.each do |action|
  #   # rollback file and image cards
  #   action.card.try :rollback_to, action
  # end
  clear_drafts
  abort :success
end


# all acts with actions on self and on cards that are descendants of self and
# included in self
def intrusive_family_acts args={}
  @intrusive_family_acts ||= begin
    Act.find_all_with_actions_on((included_descendant_card_ids << id), args)
  end
end

# all acts with actions on self and on cards included in self
def intrusive_acts args={ with_drafts: true }
  @intrusive_acts ||= begin
    Act.find_all_with_actions_on((included_card_ids << id), args)
  end
end

def current_rev_nr
  @current_rev_nr ||= begin
    if intrusive_acts.first.actions.last.draft
      @intrusive_acts.size - 1
    else
      @intrusive_acts.size
    end
  end
end

def included_card_ids
  @included_card_ids ||=
    Card::Reference.select(:referee_id).where(
      ref_type: "I", referer_id: id
    ).pluck("referee_id").compact.uniq
end

def descendant_card_ids parent_ids=[id]
  more_ids = Card.where("left_id IN (?)", parent_ids).pluck("id")
  more_ids += descendant_card_ids more_ids unless more_ids.empty?
  more_ids
end

def included_descendant_card_ids
  included_card_ids & descendant_card_ids
end

format :html do
  view :history do |args|
    frame args.merge(body_class: "history-slot list-group", content: true) do
      [history_legend, history_acts(args)]
    end
  end

  def default_history_args args
    args[:optional_toolbar] ||= :show
  end

  def history_acts args
    page = params["page"] || 1
    args[:acts] = card.intrusive_acts.page(page).per(ACTS_PER_PAGE)
    _render_act_list args
  end

  def history_legend with_drafts=true
    intr = card.intrusive_acts.page(params["page"]).per(ACTS_PER_PAGE)
    legend = render_haml intr: intr, with_drafts: with_drafts do
      <<-HAML.strip_heredoc
        .history-header
          %span.slotter
            = paginate intr, remote: true, theme: 'twitter-bootstrap-3'
          %div.history-legend
            %span.pull-left
              = action_legend with_drafts
            %span.pull-right
              Content changes:
              %span
                = Card::Content::Diff.render_added_chunk('Additions')
              |
              %span
                = Card::Content::Diff.render_deleted_chunk('Subtractions')
      HAML
    end

    bs_layout do
      row 12 do
        col legend
      end
    end
  end

  def action_legend with_drafts
    types = [:create, :update, :delete]
    legend = types.map do |action_type|
               "#{action_icon(action_type)} #{action_type}d"
    end.join " | "
    if with_drafts
      legend << " | #{action_icon(:draft)} unsaved draft"
    end
    "Actions: #{legend}"
  end

  view :content_changes do |args|
    action = args[:action]
    if args[:hide_diff]
      action.raw_view
    else
      action.content_diff(args[:diff_type])
    end
  end
end

def diff_args
  { diff_format: :text }
end

def has_edits?
  Card::Act.where(actor_id: id).where("card_id IS NOT NULL").present?
end
