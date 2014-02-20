require 'fileutils'
require 'active_support/inflector'

module Wize
  class Upgrader
    SOFT_DIR_MAPPINGS = {
      ".git" => ".git",
      "app" => "app",
      "script" => "bin",
      "db" => "db",
      "vendor" => "vendor"
    }
    HARD_DIR_MAPPINGS = {
      "config/locales" => "config/locales",
      "config/initializers" => "config/initializers"
    }
    COMMON_GEMS = [
      "gem 'jquery-rails'",
      "gem 'pg'",
      "gem 'sqlite3'",
      "gem 'rails', '3.2.10'",
      "gem 'rails', '3.2.11'",
      "gem 'rails', '3.2.12'",
      "gem 'rails', '3.2.13'",
      "gem 'rails', '3.2.14'",
      "gem 'rails', '3.2.15'"
    ]
    COMMON_FILES = [
      "config/application.yml",
      "config/database.yml",
      "config/routes.rb"
    ]

    def initialize(old_app_name)
      @old_name = "#{ old_app_name }_old" # name of rails 3 app
      @new_name = old_app_name
    end

    def upgrade
      puts "-------   UPGRADING #{ @new_name } FROM RAILS 3.2 to RAILS 4   -------"

      begin
        rename_old
        rails_gen_new
        copy_common_dirs
        copy_special_files
        upgrade_gemfile("#{ @old_name }/Gemfile", "#{ @new_name }/Gemfile")
      rescue => e
        puts e.message
        puts "something went wrong!"
      ensure
        downgrade
      end
    end

    def attr_accessibles
      @attr_accessibles ||= Hash.new { [] }
    end

    def fix_controllers
      files_for("#{ @new_name }/app/controllers").each { |c| fix_controller(c) }
    end

    def fix_controller(file)
      model = File.basename(file).gsub("_controller.rb", "").singularize
      return if attr_accessibles[model].empty?

      columns = attr_accessibles[model]
      params_block = <<-rb

    private
    def #{ model }_params
      params.require(:#{ model }).permit(#{ columns.join(", ") })
    end
  rb

      # find last occurance of end and replace with params_block
      ctrlr = File.read("#{ @new_name }/app/controllers/#{ file }")
      end_idx = ctrlr.rindex("end")
      puts "last index of end is #{ end_idx }"
      ctrlr.insert(end_idx, params_block)
      ctrlr.gsub!("params[:#{ model }]", "#{ model }_params")

      File.open("#{ @new_name }/app/controllers/#{ file }.tmp", "w") do |n|
        n.write(ctrlr)
      end
      `mv #{ @new_name }/app/controllers/#{ file }.tmp #{ @new_name }/app/controllers/#{ file }`
    end

    def fix_models
      puts "pulling out attr_accessible from models"
      files_for("#{ @new_name }/app/models").each { |m| fix_model(m) }
    end

    def fix_model(file)
      File.open("#{ @new_name }/app/models/#{ file }", "r") do |old|
        File.open("#{ @new_name }/app/models/#{ file }.tmp", "w") do |n|
          old.each_line do |line|
            if line.strip.start_with?("attr_accessible")
              lower_model = file.gsub(".rb", "")
              attr_accessibles[lower_model] += line
                .strip
                .gsub("attr_accessible", "")
                .split(",")
                .map(&:strip)
            else
              n.write(line)
            end
          end
        end
      end
      `mv #{ @new_name }/app/models/#{ file }.tmp #{ @new_name }/app/models/#{ file }`
    end

    def files_for(dir)
      [].tap do |files|
        Dir.foreach(dir) do |node|
          next if node.start_with?(".")
          files << node if node.end_with?(".rb")
          if File.directory?("#{ dir }/#{ node }")
            sub_files = files_for("#{ dir }/#{ node }")
            sub_files.map! { |f| "#{ node }/#{ f }" }
            files += sub_files
          end
        end
      end
    end

    def downgrade
      `mv #{ @new_name }/ #{ @new_name }_arch/`
      `mv #{ @old_name }/ #{ @new_name }/`
    end

    def upgrade_gemfile(from, to)
      # gsub " for '
      File.open(to, "a") do |f|
        unusual_gems(from).each do |gem|
          f.write(gem)
        end
      end
    end

    def unusual_gems(gemfile)
      old_gems = File.readlines(gemfile)
      old_gems.select! do |gem|
        gem.start_with?("gem") && !COMMON_GEMS.include?(gem.chomp)
      end
      puts "Special gems: "
      old_gems
    end

    def rails_gen_new
      `rails new #{ @new_name } -T`
      `cd #{ @new_name }`
      `mkdir .git`
      `cd ..`
    end

    def rename_old
      `mv #{ @new_name } #{ @old_name }`
    end

    def copy_common_dirs
      SOFT_DIR_MAPPINGS.each do |src, dest|
        `cp -rn #{ @old_name }/#{ src }/* #{ @new_name }/#{ dest }/`
      end
      HARD_DIR_MAPPINGS.each do |src, dest|
        next if src.include?("wrap_parameters")
        `cp -r #{ @old_name }/#{ src }/* #{ @new_name }/#{ dest }/`
      end
    end

    def copy_special_files
      COMMON_FILES.each do |file|
        `cp #{ @old_name }/#{ file } #{ @new_name }/#{ file }`
      end
    end
  end
end

