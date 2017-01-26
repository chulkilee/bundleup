require 'rugged'

module Bundleup
  class Runner
    attr_reader :repo, :opts

    def initialize(opts)
      @opts = opts
    end

    def call
      @repo = ::Rugged::Repository.discover(Dir.pwd)

      prepare_branch
      checkout_branch

      update_bundle

      add_changes

      gem_changes = parse_diff
      message = build_message(gem_changes)

      commit_changes(message)
    end

    def prepare_branch
      existing = repo.branches[opts[:branch_name]]
      if existing
        if opts[:force]
          # TODO: if it's the current HEAD
          repo.branches.delete(opts[:branch_name])
        else
          raise "#{opts[:branch_name]} branch already exists"
        end
      end
      repo.branches.create(opts[:branch_name], 'HEAD')
    end

    def checkout_branch
      repo.checkout(opts[:branch_name])
    end

    def update_bundle
      system('bundle update')
      # TODO: check exit status
    end

    def add_changes
      repo.index.add('Gemfile.lock')
      repo.index.write
    end

    def parse_diff
      DetectGemChanges.new.call(repo.head.target.tree.diff(repo.index))
    end

    def build_message(gem_changes)
      BuildMessage.new.call(gem_changes)
    end

    def commit_changes(message)
      commit_opts = {
        tree: repo.index.write_tree(repo),
        author: { email: repo.config.get('user.email'), name: repo.config.get('user.name'), time: Time.now },
        message: message,
        parents: [repo.head.target],
        update_ref: 'HEAD'
      }
      ::Rugged::Commit.create(repo, commit_opts)
    end
  end

  class SpecChange
    attr_reader :op, :name, :from, :to

    def initialize(op, name, from, to)
      @op = op
      @name = name
      @from = from
      @to = to
    end
  end

  class DetectGemChanges
    # TODO: should it return array instead of hash?
    def call(diff)
      result = {}
      diff.each_line do |l|
        next unless %i(addition deletion).include?(l.line_origin)
        next unless gemfile_lock_spec_line?(l.content)
        name, version = parse_gemfile_lock_spec_line(l.content)
        op = nil
        from = nil
        to = nil
        if result[name]
          # deletion always comes before addition
          op = :upgrade
          from = result[name].from
          to = version
        elsif l.line_origin == :addition
          op = :add
          to = version
        else
          op = :remove
          from = version
        end
        result[name] = SpecChange.new(op, name, from, to)
      end
      result
    end

    private

    def gemfile_lock_spec_line?(line)
      /^    \S/ =~ line
    end

    def parse_gemfile_lock_spec_line(line)
      unless /^    (?<name>\S+) \((?<version>\S+)\)$/ =~ line
        raise "fail to parse #{line}"
      end

      [name, version]
    end
  end

  class BuildMessage
    def call(gem_changes)
      by_kind = group_by_kind(gem_changes)

      lines = [first_line]
      by_kind.each do |op, cs|
        lines += ['', op_to_title[op], '']
        lines += cs.map { |c| format_spec_change(c) }
      end
      lines.join("\n")
    end

    private

    def group_by_kind(gem_changes)
      by_kind = gem_changes.each_with_object({}) do |(_, c), m|
        m[c.op] ||= []
        m[c.op] << c
      end
      by_kind.reject { |_, v| v.empty? }
    end

    def op_to_title
      {
        upgrade: 'upgraded:',
        add: 'added:',
        remove: 'removed:'
      }
    end

    def first_line
      'update bundle deps'
    end

    def format_spec_change(sc)
      case sc.op
      when :upgrade
        "* #{sc.name}: #{sc.from} => #{sc.to}"
      when :add
        "* #{sc.name}: #{sc.to}"
      when :delete
        "* #{sc.name}: #{sc.from}"
      end
    end
  end
end
