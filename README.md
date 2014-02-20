# Wize Upgrader Gem

This gem is for upgrading basic Rails 3.2 apps to Rails 4.

We have to upgrade a bunch of apps from Rails 3.2 to Rails 4. We built this gem 
to help. **NB**: most of our apps are simple, but this should handle 95% of the 
cases out there.

## Getting started

```sh
$ gem install wize_upgrader
```

Run it from outside of your rails app.

```sh
$ wize_upgrader <rails_app_dir>
```

## What it does
+  makes a copy of old app to <rails_app_dir>_old
+  generates a new rails app with `rails new <rails_app_dir> -T`
+  copies over
   +  .git
   +  app
   +  db
   +  script => bin
   +  spec
   +  vendor
   +  config/routes.rb
   +  config/initializers (except wrap_parameters.rb)
   +  config/locales
+  removes references to attr_accessible in models
+  uses attr_accessible list to create *_params method in related controllers

## Requirements

+   `fileutils`
+   `active_support/inflector`
