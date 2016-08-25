require 'date'

class AddressInformation
  attr_reader :client

  @@neighborhood_to_pd = {"Mission" => "Mission", "Bernal Heights" => "Ingleside", "Central Richmind" => "Richmond", "Excelsior" => "Ingleside", "Bayview" => "Bayview", "Central Sunset" => "Taraval", "Downtown" => "Tenderloin", "Pacific Heights" => "Northern", "Nob Hill" => "Central", "Visitacion Valley" => "Ingleside", "Parkside" => "Taraval", "Inner Richmond" => "Richmond", "South of Market" => "Southern", "Tenderloin" => "Tenderloin", "Noe Valley" => "Ingleside", "Inner Sunset" => "Taraval", "Outer Sunset" => "Taraval", "Portola" => "Bayview", "Russian Hill" => "Central", "Outer Parkside" => "Taraval"}

  #Population for 2008 census
  @@neighborhood_population = {"Mission" => 47234, "Bernal Heights" => 24824, "Central Richmind" =>   59297, "Excelsior" => 23823, "Bayview" => 35890, "Central Sunset" => 21791, "Downtown" => 38728, "Pacific Heights" => 23545, "Nob Hill" => 20388, "Visitacion Valley" =>  22534 , "Parkside" => 27640, "Inner Richmond" => 38939, "South of Market" => 23016, "Tenderloin" => 25067, "Noe Valley" => 21106, "Inner Sunset" => 38892, "Outer Sunset" =>  77431, "Portola" => 12760, "Russian Hill" => 56322, "Outer Parkside" => 14334}

  @@police_population = {"Mission" => 47234 / 653561.0 , "Ingleside" => (24824 + 23823 + 22534 + 21106) / 653561.0, "Richmond" =>  (59297 + 38939) / 653561.0, "Bayview" => (35890 + 12760) / 653561.0, "Taraval" => (27640 + 38892 + 77431 + 14334 + 21791) / 653561.0, "Central" => (56322 + 20388) / 653561.0, "Tenderloin" => (38728 + 25067) / 653561.0, "Southern" => 23016 / 653561.0, "Northern" => 23545 / 653561.0}

  @@total_population = 653561.0

  def initialize
    @client = SODA::Client.new({:domain => "data.sfgov.org", :app_token => ENV["SF_DATA_TOKEN"]})
  end

  def convert_to_station(neighborhood)
    @@neighborhood_to_pd[neighborhood]
  end

  def eviction_notices_in(neighborhood, year)
    zipcode = zipcode.to_s
    client.get("93gi-sfd2", {
      "$select" => "count(neighborhood) as neighborhood_evictions",
      "$where" =>  "neighborhood like '#{neighborhood}' and date_trunc_y(file_date) between '#{year}' and '2015'",
      "$group" => "neighborhood"
      })
  end

  def total_eviction_notices
    zipcode = zipcode.to_s
    client.get("93gi-sfd2", {
      "$select" => "count(neighborhood) as evictions",
      "$where" => "date_trunc_y(file_date) between '2015' and '2015'"
      })
  end

  def firesafety_complaints_in(neighborhood, year)
    client.get("x75j-u3wx", {
      "$select" => 'count(neighborhood_district) as neighborhood_fire_complaints',
      "$where" => "neighborhood_district like '#{neighborhood}' and date_trunc_y(violation_date) between '#{year}' and '2015'",
      })

  end

  def total_firesafety_complaints
    client.get("x75j-u3wx", {
      "$select" => 'count(neighborhood_district) as total_firesafety_complaints',
      "$where" => "date_trunc_y(violation_date) = '2015'"
      })
  end

  def total_neighborhoods
    20
  end


  def crime_in_neighborhood(neighborhood, year)
    client.get("cuks-n6tp", {
      "$select" => "count(pddistrict) as crimes_neighborhood",
      "$where" => "lower(pddistrict) like '#{convert_to_station(neighborhood).downcase}' and date_trunc_y(date) between '#{year}' and '2015'"
      })
  end

  def total_crime
    client.get("cuks-n6tp", {
      "$select" => "count(incidntnum)",
      "$where" => "date_trunc_y(date) = '2015'"
      })
  end

  def fire_incidents_in(neighborhood, year)
    @client.get("wbb6-uh78", {
      "$select" => "count(neighborhood_district) as fire_incidents",
      "$where" => "'#{neighborhood.downcase}' like lower(neighborhood_district) and date_trunc_y(alarm_dttm) between '2015' and '#{year}'"
    })
  end

  def total_fire_incidents
    client.get("wbb6-uh78", {
      "$select" => "count(neighborhood_district) as fire_incidents",
      "$where" => "date_trunc_y(alarm_dttm) = '2015'"
      })
  end

  # def traffic_incidents_in(neighborhood, year)
  #   client.get("vv57-2fgy", {
  #     "$select" => "count(incidntnum) as traffic_incidents",
  #     "$where" => "lower(pddistrict) like '#{convert_to_station(neighborhood).downcase}' and date_trunc_y(date) between '#{year}' and '2015'"
  #     })
  # end

  def total_traffic_incidents
    client.get("cuks-n6tp", {
      "$select" => "count(incidntnum) as total_traffic_incidents",
      "$where" => "date_trunc_y(date) = '2015' and descript like '%TRAFFIC VIOLATIONS%'"
      })
  end

  def neighborhood_population_ratio(neighborhood)
    @@neighborhood_population[neighborhood] / @@total_population
  end

  def police_population_ratio(neighborhood)
    @@police_population[convert_to_station(neighborhood)]
  end


  def eviction_score(neighborhood, year)
    score = ((eviction_notices_in(neighborhood, year).first.first[1].to_i.to_f / total_eviction_notices.first.first[1].to_i) / neighborhood_population_ratio(neighborhood)) * 2.5
    if score >= 5.0
      5
    else
      score.round
    end
  end


  def fire_safety_score(neighborhood, year)
    score = ((firesafety_complaints_in(neighborhood, year).first.first[1].to_i.to_f / total_firesafety_complaints.first.first[1].to_i) / neighborhood_population_ratio(neighborhood)) * 2.5
    if score >= 5.0
      5
    else
      score.round
    end
  end


  def crime_score(neighborhood, year)
    score = ((crime_in_neighborhood(neighborhood, year).first.first[1].to_i.to_f / total_crime.first.first[1].to_i) / police_population_ratio(neighborhood)) * 2.5
    if score >= 5.0
      5
    else
      score.round
    end
  end

  def fire_incidents_score(neighborhood, year)
    score = ((fire_incidents_in(neighborhood, year).first.first[1].to_i.to_f / total_fire_incidents.first.first[1].to_i) / neighborhood_population_ratio(neighborhood)) * 2.5
    if score >= 5.0
      5
    else
      score.round
    end
  end

  def traffic_violations_score


  end

end