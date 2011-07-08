# This script provides a nice generalised and ideally easy to maintain set of backup data for youthtree applications.
# It was built on top of the backup gem, version 2.

 # What rails env is this machine running as?
RAILS_ENV      = 'production'
YT_BACKUP_PATH = lambda { |app_name, backup_type| "/backup/#{app_name}/#{RAILS_ENV}" }
YT_BACKUP_NAME = lambda do |app_name, backup_type|
  short_name   = [:mongo, :postgresql].include?(backup_type) ? :db : :contents
  "#{app_name}-#{RAILS_ENV}-#{short_name}"
end

YT_BACKUP_COUNTS = {
  :postgresql => 90,
  :mongo      => 30,
  :archive    => 30
}

# A hash of app name -> db name for postgres
PG_DATABASES = {
  :bighelpmob           => "bighelpmob_#{RAILS_ENV}",
  :wiki                 => "wiki_#{RAILS_ENV}",
  :teambox              => "teambox_#{RAILS_ENV}",
  :mortimer             => "mortimer_#{RAILS_ENV}",
  :site                 => "yt_#{RAILS_ENV}",
  :recruitment_platform => "recruitment_platform_#{RAILS_ENV}"
}

# A hash of app name -> db name for mongodb
MONGO_DATABASES = {
  :errbit => "errbit_#{RAILS_ENV}"
}

# A hash of site name -> array of files
SITE_FILES = {
  :wiki     => "/opt/wiki/#{RAILS_ENV}/current/",
  :teambox  => "/opt/teambox/#{RAILS_ENV}/current/",
  :mortimer => ["/opt/mortimer/#{RAILS_ENV}/current/", "/opt/mortimer/root_key.rsa"],
  :site     => "/opt/site/#{RAILS_ENV}/current/"
}

# A hash of site name -> array of excludes
SITE_EXCLUDES = {
  :wiki => "/opt/wiki/#{RAILS_ENV}/current/cache"
}

def declare_backup(app_name, type, &block)
  # Declare the backup using a calculated name
  backup YT_BACKUP_NAME.call(app_name, type) do
    # Short hand to configure the adapter.
    adapter(type, &block)
    # Default storage into the correct path
    storage :local do
      path YT_BACKUP_PATH.call(app_name, type)
    end
    # Finally, set up some sane options.
    keep_backups          YT_BACKUP_COUNTS[type]
    encrypt_with_password false
    notify                false
  end
end

# Actually generate backup configurations for each set of data.

PG_DATABASES.each_pair do |app_name, database_name|
  declare_backup app_name, :postgresql do
    user               'backups'
    additional_options '--clean --blobs'
    database           database_name
  end
end

MONGO_DATABASES.each_pair do |app_name, database_name|
  declare_backup app_name, :mongo do
    database database_name
  end
end

SITE_FILES.each_pair do |app_name, backup_paths|
  app_files    = Array(backup_paths)
  app_excludes = Array(SITE_EXCLUDES[app_name])
  declare_backup app_name, :archive do
    files   app_files
    exclude app_excludes unless app_excludes.empty?
  end
end

# Finally, declare a task just for server configuration items.
backup 'server-configuration' do
  adapter :archive do
    files ["/etc/nginx", "/etc/unicorn.default", "/etc/init.d/unicorn"] + Dir["/opt/*/*/current/config/unicorn.rb"]
  end
  storage :local do
    path '/backup/server-configuration/'
  end
  keep_backups          90
  encrypt_with_password false
  notify                false
end