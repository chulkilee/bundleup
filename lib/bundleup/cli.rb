require 'thor'

# TODO: use logger
# TODO: use verbose mode
# TODO: return exit code

module Bundleup
  class CLI < Thor
    option :force, type: :boolean, default: false
    option :branch_name, type: :string, default: 'bundleup'
    desc 'all', ''
    def all
      Runner.new(options).call
    end
    default_task :all
  end
end
