class GitTagger
  
  attr_reader :git, :tags, :branch, :commit, :namespace
  
  def initialize(namespace = "", options = {})
    @namespace          = namespace
    @git                = `which git`.chomp
    @tags               = `#{@git} tag`.collect { |tag| tag.chomp }
    @branch             = `#{@git} branch | awk '/\\*/ { print $2 }'`.chomp
    @commit             = `#{@git} log | awk '/^commit/ { print $2 }' | head -n 1`.chomp
    @commit_tag_length  = options.has_key?(:commit_tag_length) ? options[:commit_tag_length].to_i : 6
    @timestamp          = options.has_key?(:timestamp) ? options[:timestamp] : '%Y%m%d'
  end
  
  def deploy_tags
    tags.grep(/^#{namespace}-#{timestamp}-(\d{2})/)
  end

  def build_number
    deploy_tags.size + 1
  end

  def commit_tag
    commit[0..@commit_tag_length]
  end

  def tag_name
    namebits = []
    namebits << namespace
    namebits << timestamp if @timestamp
    namebits << sprintf("%02d", build_number)
    namebits << branch unless branch == 'master'
    namebits << commit_tag
    namebits.join('-')
  end

  def timestamp
    Time.now.strftime(@timestamp)
  end
  
  def tag(*args)
    options = args.last.is_a?(Hash) ? args.pop : {}
    names   = args.empty? ? options[:delete] ? [] : [ tag_name ] : args
    `#{git} tag #{'-f ' if options[:force]}#{'-d ' if options[:delete]}#{names.join(' ')}` unless names.empty?
  end

  def push(*args)
    options   = {
      :tags   => true,
      :force  => true
    }.merge(args.last.is_a?(Hash) ? args.pop : {})
    remote    = args[0] || "origin"
    refstring = make_refstring(options[:refs])
    `#{git} push#{' --tags' if options[:tags]}#{' --force' if options[:force]}#{" #{remote} " + refstring if refstring}`
  end
  
  def clean(keep = 20)
    tag(old_tags_refspec(keep), :delete => true)
  end
  
  private

  def old_tags(number)
    deploy_tags[number..-1] || []
  end    
  
  def old_tags_refspec(number)
    old_tags(number).collect { |tag| ":#{tag}" }
  end
  
  def make_refstring(refs)
    case refs
    when Hash
      refs.inject("") { |str, (local, remote)| str << "#{local}:#{remote}" }
    when Array
      refs.join(' ')
    when String
      refs
    else
      nil
    end
  end
  
end