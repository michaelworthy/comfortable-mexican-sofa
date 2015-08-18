class Cms::Revision < ActiveRecord::Base
  include Cms::Base
  
  serialize :data
  
  # -- Relationships --------------------------------------------------------
  belongs_to :record, :polymorphic => true, :touch => true
  
  # -- Scopes ---------------------------------------------------------------
  default_scope -> { order('created_at DESC') }
  
end