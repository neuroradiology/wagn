# -*- encoding : utf-8 -*-

class RemoveEditToolbarPinned < Card::Migration::Core
  def up
    card = Card[:edit_toolbar_pinned]
    card.update_attributes! codename: nil
    card.delete
  end
end
