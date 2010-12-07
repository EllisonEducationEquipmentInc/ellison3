module OldData
  class IdeaTabsIdea < ActiveRecord::Base
    belongs_to :idea
    belongs_to :idea_tab
  end
end