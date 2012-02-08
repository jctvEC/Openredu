class License < ActiveRecord::Base
  belongs_to :invoice

  validates_presence_of :name, :email, :period_start, :role
  validates_format_of :email, :with => /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i

  scope :in_use, where(:period_end => nil)
end
