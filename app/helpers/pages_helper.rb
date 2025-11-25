module PagesHelper
  def journey_badge_label_and_class(badge)
    case badge.to_sym
    when :evergreen
      [ "badge-warning", "Evergreen" ]
    when :all_time_favorite
      [ "badge-success", "All-Time Favorite" ]
    when :new_obsession
      [ "badge-success", "New Obsession" ]
    when :fading_out
      [ "badge-danger", "Fading Out" ]
    when :short_term
      [ "badge-info", "Short-Term Crush" ]
    else
      [ "badge-secondary", badge.to_s.humanize ]
    end
  end
end
