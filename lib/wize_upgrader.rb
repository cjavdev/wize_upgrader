require 'fileutils'
require 'active_support/inflector'
require 'debugger'

module Wize
  class Upgrader
    SOFT_DIR_MAPPINGS = {
      ".git" => ".git",
      "script" => "bin",
      "db" => "db",
      "lib" => "lib",
      "spec" => "spec",
      "vendor" => "vendor"
    }
    HARD_DIR_MAPPINGS = {
      "app" => "app",
      "config/locales" => "config/locales",
      "config/initializers" => "config/initializers"
    }
    COMMON_GEMS = [
      "gem 'jquery-rails'",
      "gem 'rspec-rails'",
      "gem 'jbuilder'",
      "gem 'coffee-rails', '~> 3.2.1'",
      "gem 'sass-rails',   '~> 3.2.3'",
      "gem 'uglifier', '>= 1.0.3'",
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
      "config/routes.rb",
      "README.md"
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
        upgrade_gemfile("#{ @old_name }/Gemfile", "#{ @new_name }/Gemfile")
        install_rspec
        copy_common_dirs
        copy_special_files
        fix_models
        fix_controllers
        version_control
      rescue => e
        puts e.message
        puts e.backtrace
        puts "something went wrong!"
      ensure
      end
      puts "------    DONE UPGRADING! HAVE FUN    ------"
    end

    def version_control
      Dir.chdir(@new_name)
      puts `git add -A`
      `git commit -m "upgraded to rails 4 with wize_upgrader"`
      puts `git push`
      Dir.chdir("..")
    end

    def install_rspec
      `cd #{ @new_name }`
      `bundle install`
      `rails g rspec:install`
      `cd ..`
    end

    def attr_accessibles
      @attr_accessibles ||= Hash.new { [] }
    end

    def fix_controllers
      files_for("#{ @new_name }/app/controllers").each { |c| fix_controller(c) }
    end

    def fix_controller(file)
      puts "fixing #{ file }"
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
      lower_model = file.gsub(".rb", "")
      puts "fixing #{ lower_model }"
      File.open("#{ @new_name }/app/models/#{ file }", "r") do |old|
        File.open("#{ @new_name }/app/models/#{ file }.tmp", "w") do |n|
          old.each_line do |line|
            if line.strip.start_with?("attr_accessible")
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
      puts "Found attr_accessible #{ attr_accessibles[lower_model].join(", ") }"
      `mv #{ @new_name }/app/models/#{ file }.tmp #{ @new_name }/app/models/#{ file }`
    end

    def files_for(dir)
      puts "Files for: #{ dir }"
      files = []
      Dir.foreach(dir) do |node|
        next if node.start_with?(".")
        files << node if node.end_with?(".rb")
        if File.directory?("#{ dir }/#{ node }")
          sub_files = files_for("#{ dir }/#{ node }")
          sub_files.map! { |f| "#{ node }/#{ f }" }
          files += sub_files
        end
      end
      p files
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

        f.write(<<-rb)
group :development, :test do
  gem 'rspec-rails'
end
        rb
      end
    end

    def unusual_gems(gemfile)
      old_gems = File.readlines(gemfile)
      old_gems.select! do |gem|
        gem.strip.start_with?("gem") && !COMMON_GEMS.include?(gem.strip)
      end
      puts "CHECK THE GEM GROUPS!!"
      puts "Special gems: "
      old_gems
    end

    def rails_gen_new
      puts "Generating new rails app <#{ app_name }>"
      puts `rails new #{ app_name } -T`
      puts "Renaming #{ app_name } to #{ @new_name }"
      `mv #{ app_name } #{ @new_name }`
      `rm #{ @new_name }/README.rdoc`
    end

    def rename_old
      puts "Renaming #{ @new_name } to #{ @old_name }"
      `mv #{ @new_name } #{ @old_name }`
    end

    def app_name
      @app_name ||= begin
        lines = File.readlines("#{ @old_name }/config/application.rb")
        lines.select! { |l| l.start_with?("module") }
        lines.first.gsub("module", "").strip
      end
    end

    def copy_common_dirs
      SOFT_DIR_MAPPINGS.each do |src, dest|
        if Dir.exists?("#{ @new_name }/#{ dest }")
          `cp -rn #{ @old_name }/#{ src }/* #{ @new_name }/#{ dest }/`
        else
          `cp -r #{ @old_name }/#{ src } #{ @new_name }`
        end
      end
      HARD_DIR_MAPPINGS.each do |src, dest|
        next if src.include?("wrap_parameters")
        if Dir.exists?("#{ @new_name }/#{ dest }")
          `cp -r #{ @old_name }/#{ src }/* #{ @new_name }/#{ dest }/`
        else
          `cp -r #{ @old_name }/#{ src } #{ @new_name }`
        end
      end
    end

    def copy_special_files
      COMMON_FILES.each do |file|
        `cp #{ @old_name }/#{ file } #{ @new_name }/#{ file }`
      end
    end
  end
end

