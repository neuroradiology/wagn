# -*- encoding : utf-8 -*-

class Card
  module Set
    # the set loading process has two main phases:

    #  1. Definition: interpret each set file, creating/defining set and
    #     set_format modules
    #  2. Organization: have base classes include modules associated with the
    #     'all' set, and clean up the other modules
    module Loader
      # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
      # Definition Phase

      # each set file calls `extend Card::Set` when loaded
      def extended mod
        register_set mod
      end

      # make the set available for use
      def register_set set_module
        if set_module.all_set?
          # automatically included in Card class
          modules[:base] << set_module
        else
          set_type = set_module.abstract_set? ? :abstract : :nonbase
          # made ready for dynamic loading via #include_set_modules
          modules[set_type][set_module.shortname] ||= []
          modules[set_type][set_module.shortname] << set_module
        end
      end

      #
      #  When a Card application loads, it uses set modules to autogenerate
      #  tmp files that add module names (Card::Set::PATTERN::ANCHOR) and
      #  extend the module with Card::Set.

      #
      def write_tmp_file from_file, to_file, rel_path
        pattern, submodules = pattern_and_modules_from_path rel_path
        FileUtils.mkdir_p File.dirname(to_file)
        File.write to_file, tmp_file_template(pattern, submodules, from_file)
        to_file
      end

      def pattern_and_modules_from_path path
        # remove file extension and number prefixes
        parts = path.gsub(/\.rb/, "").gsub(%r{(?<=\A|/)\d+_}, "")
                    .split(File::SEPARATOR)
        parts.map! &:camelize
        [parts.shift, parts]
      end

      def tmp_file_template pattern, modules, content_path
        content = File.read(content_path)
        wrapped_content = tmp_file_wrapped_content content_path, content

        # TODO: load directly without tmp file
        return wrapped_content if content =~ /\A#!\s?simple load/

        submodules = modules.map { |m| "module #{m};" }
        if content =~ /\A#!\s?not? set module/
          submodules.pop
        else
          submodules[-1] += " extend Card::Set"
        end
        tmp_file_frame pattern, submodules, wrapped_content, content_path
      end

      def tmp_file_frame pattern, submodules, content, content_path
<<-RUBY
# -*- encoding : utf-8 -*-
class Card; module Set; class #{pattern}; #{submodules.join ' '}
  def self.source_location; "#{content_path}"; end
#{content}
end;end;end;#{'end;' * submodules.size}
RUBY
      end

      def tmp_file_wrapped_content content_path, content
<<-RUBY
# ~~ above autogenerated; below pulled from #{content_path} ~~
#{content}

# ~~ below autogenerated; above pulled from #{content_path} ~~
RUBY
      end

      # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
      # Organization Phase

      # 'base modules' are modules that are permanently included on the Card or
      # Format class
      # 'nonbase modules' are included dynamically on singleton_classes
      def process_base_modules
        return unless modules[:base]
        Card.add_set_modules modules[:base]
        modules[:base_format].each do |format_class, modules_list|
          format_class.add_set_modules modules_list
        end
        modules.delete :base
        modules.delete :base_format
      end

      def clean_empty_modules
        clean_empty_module_from_hash modules[:nonbase]
        modules[:nonbase_format].values.each do |hash|
          clean_empty_module_from_hash hash
        end
      end

      def clean_empty_module_from_hash hash
        hash.each do |mod_name, modlist|
          modlist.delete_if { |x| x.instance_methods.empty? }
          hash.delete mod_name if modlist.empty?
        end
      end
    end
  end
end
