# Wize Upgrader Gem

This gem is for upgrading basic Rails 3.2 apps to Rails 4.

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
+  removes references to attr_accessible in models
+  uses attr_accessible list to create *_params method in related controllers

## Requirements

+   `fileutils`
+   `active_support/inflector`
