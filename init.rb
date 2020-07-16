require 'redmine_google_chat'

Redmine::Plugin.register :redmine_google_chat do
	name 'Redmine Google Chat plugin'
	author 'Changho Song'
	url 'https://github.com/lunakillz/redmine_google_chat'
	description 'A Redmine plugin posts Google Chat on creating and updating tickets'
	version '0.1'
	permission :manage_hook, {:webhook_settings => [:index, :show, :update, :create, :destroy]}, :require => :member
	requires_redmine :version_or_higher => '4.0.0'

	settings \
		:default => {
			'callback_url' => 'https://chat.googleapis.com/v1/',
		},
		:partial => 'settings/google_chat_settings'
end
l