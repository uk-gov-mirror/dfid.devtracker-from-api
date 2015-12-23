#require "helpers/project_helpers"

module RegionHelpers

  include ProjectHelpers
  include CommonHelpers

  def get_region_code_name(regionCode)
      regionInfo = JSON.parse(File.read('data/dfidRegions.json'))
      region = regionInfo.select {|region| region['code'] == regionCode}.first
      returnObject = {
            :code => region['code'],
            :name => region['name']
            }
  end

  def get_region_details(regionCode)

      firstDayOfFinYear = first_day_of_financial_year(DateTime.now)
      lastDayOfFinYear = last_day_of_financial_year(DateTime.now)
      
      regionInfo = JSON.parse(File.read('data/dfidRegions.json'))
      region = regionInfo.select {|region| region['code'] == regionCode}.first
      
      currentTotalRegionBudget= get_current_total_budget(RestClient.get settings.oipa_api_url + "activities/aggregations?format=json&reporting_organisation=GB-1&budget_period_start=#{firstDayOfFinYear}&budget_period_end=#{lastDayOfFinYear}&group_by=recipient_region&aggregations=budget&recipient_region=#{regionCode}")
      currentTotalDFIDBudget = get_current_dfid_total_budget(RestClient.get settings.oipa_api_url + "activities/aggregations?format=json&reporting_organisation=GB-1&budget_period_start=#{firstDayOfFinYear}&budget_period_end=#{lastDayOfFinYear}&group_by=reporting_organisation&aggregations=budget")

      totalProjectsDetails = get_total_project(RestClient.get settings.oipa_api_url + "activities?reporting_organisation=GB-1&hierarchy=1&related_activity_recipient_region=#{regionCode}&format=json&fields=activity_status&page_size=250")
      totalActiveProjects = totalProjectsDetails['results'].select {|status| status['activity_status']['code'] =="2" }.length

      
      if currentTotalRegionBudget['count'] > 0 then
          if currentTotalRegionBudget['results'][0]['budget'].nil? then
              regionBudget = 0
          else
              regionBudget = currentTotalRegionBudget['results'][0]['budget']
          end    
      else
          regionBudget = 0
      end

      totalDfidBudget = currentTotalDFIDBudget['results'][0]['budget']
      
      projectBudgetPercentToDfidBudget = ((regionBudget.round(2) / totalDfidBudget.round(2))*100).round(2)

    
      returnObject = {
            :code => region['code'],
            :name => region['name'],
            :description => region['description'],
            :type => region['type'],
            :url => region['url'],
            :totalProjects => totalProjectsDetails['count'],
            :totalActiveProjects => totalActiveProjects,
            :regionBudget => regionBudget,
            :regionBudgetCurrency => "GBP",
            :projectBudgetPercentToDfidBudget => projectBudgetPercentToDfidBudget
            }
  end

  def dfid_complete_region_list(regionType)        
        regionsList = JSON.parse(File.read('data/dfidRegions.json')).select{|r| r["type"]==regionType}.sort_by{ |k| k["name"]}    
    end

    def dfid_regional_projects_data(regionType)
        
        firstDayOfFinYear = first_day_of_financial_year(DateTime.now)
        lastDayOfFinYear = last_day_of_financial_year(DateTime.now)

        if (regionType=="region")
            regionsDataJSON = RestClient.get settings.oipa_api_url + "activities/aggregations?format=json&reporting_organisation=GB-1&budget_period_start=#{firstDayOfFinYear}&budget_period_end=#{lastDayOfFinYear}&group_by=recipient_region&aggregations=count,budget&recipient_region_not_in=NS,ZZ"
        else
            regionsDataJSON = RestClient.get settings.oipa_api_url + "activities/aggregations?format=json&reporting_organisation=GB-1&budget_period_start=#{firstDayOfFinYear}&budget_period_end=#{lastDayOfFinYear}&group_by=recipient_region&aggregations=count,budget&recipient_region=NS,ZZ"
        end
            
        # aggregates budgets of the dfid regional projects that are active in the current FY
        #oipaAllRegionsJSON = RestClient.get settings.oipa_api_url + "activities/aggregations?format=json&reporting_organisation=GB-1&budget_period_start=#{settings.current_first_day_of_financial_year}&budget_period_end=#{settings.current_last_day_of_financial_year}&group_by=recipient_region&aggregations=count,budget";
        allCurrentRegions = JSON.parse(regionsDataJSON)
        allCurrentRegions = allCurrentRegions['results']

        # Map the input data structure so that it matches the required input for the Regions map
        allRegionsChartData = allCurrentRegions.map do |elem|
        {
            "region" => elem["recipient_region"]["name"].to_s.gsub(", regional",""),
            "code" => elem["recipient_region"]["code"],
            "budget" => elem["budget"]                           
        }
        end
               
        # Find the total budget for all of the Regions
        totalBudget = Float(allRegionsChartData.map { |s| s["budget"].to_f }.inject(:+))

        # Format the Budget for use on the region chart
        totalBudgetFormatted = (format_million_stg totalBudget.to_f).to_s.gsub("&pound;","")

        # Format the output of the chart data
        allRegionsChartDataFormatted = allRegionsChartData.to_s.gsub("=>",":")

        returnObject = {
            :regionsDataJSON => allRegionsChartData,
            :regionsData => allRegionsChartDataFormatted,            
            :totalBudget => totalBudget,  
            :totalBudgetFormatted => totalBudgetFormatted                              
        }
    end

    #Here variable n  = related_activity_recipient_region
  def get_region_projects(n)
      oipa_project_list = RestClient.get settings.oipa_api_url + "activities/?hierarchy=1&format=json&reporting_organisation=GB-1&page_size=10&fields=description,activity_status,iati_identifier,url,title,reporting_organisations,activity_plus_child_aggregation&activity_status=1,2,3,4,5&ordering=-activity_plus_child_budget_value&related_activity_recipient_region=#{n}"
      projects= JSON.parse(oipa_project_list)
      results = {}
      sectorValuesJSON = RestClient.get settings.oipa_api_url + "activities/aggregations/?format=json&group_by=sector&aggregations=count&reporting_organisation=GB-1&related_activity_recipient_region=#{n}"
      results['highLevelSectorList'] = high_level_sector_list_filter(sectorValuesJSON)
      results['project_budget_higher_bound'] = 0
      results['actualStartDate'] = '1990-01-01T00:00:00' 
      results['plannedEndDate'] = '2000-01-01T00:00:00'
      unless projects['results'][0].nil?
        begin
          results['project_budget_higher_bound'] = projects['results'][0]['activity_plus_child_aggregation']['budget_value']
        rescue
          results['project_budget_higher_bound'] = 0
        end
      end
      ###results['actualStartDate'] = RestClient.get settings.oipa_api_url + "activities?format=json&page_size=1&fields=activity_dates&reporting_organisation=GB-1&hierarchy=1&related_activity_recipient_region=#{n}&ordering=actual_start_date"
      ###results['actualStartDate'] = JSON.parse(results['actualStartDate'])
      ###unless results['actualStartDate']['results'][0].nil? 
        ###results['actualStartDate'] = results['actualStartDate']['results'][0]['activity_dates'][1]['iso_date']
      ###end
      ###results['plannedEndDate'] = RestClient.get settings.oipa_api_url + "activities?format=json&page_size=1&fields=activity_dates&reporting_organisation=GB-1&hierarchy=1&related_activity_recipient_region=#{n}&ordering=-planned_end_date"
      ###results['plannedEndDate'] = JSON.parse(results['plannedEndDate'])
      ###unless results['plannedEndDate']['results'][0].nil?
        ###if !results['plannedEndDate']['results'][0]['activity_dates'][2].nil?
          ###results['plannedEndDate'] = results['plannedEndDate']['results'][0]['activity_dates'][2]['iso_date']
        ###else
          #This is an issue. For now it's a temporary remedy used to avoid a ruby error but, this needs to be fixed once zz helps out with the api call to return the actual/planned end date.
          ###results['plannedEndDate'] = '2050-12-31T00:00:00'
        ###end
      ###end
      results['projects'] = projects
      return results
  end

  def global_list
      dfid_global_projects.select { |region| region[:budget] > 0 }.sort_by { |region| region[:region].upcase}
  end

  # def dfid_global_projects_data
        
  #       globalProjectsData = JSON.parse(File.read('data/globalProjectsData.json')).sort_by{ |k| k["region"]}

  #       #Format the output of globalProjectsData
  #       globalProjectsDataFormatted = globalProjectsData.to_s.gsub("=>",":")

  #       #Find the total budget for all of the Regions
  #       totalBudget = Float(globalProjectsData.map { |s| s["budget"].to_f }.inject(:+))

  #       #Format the Budget for use on the region chart
  #       totalBudgetFormatted = (format_million_stg totalBudget.to_f).to_s.gsub("&pound;","")

  #       returnObject = {
  #           :globalData => globalProjectsDataFormatted,
  #           :globalDataJSON => globalProjectsData,
  #           :totalBudget => totalBudget,  
  #           :totalBudgetFormatted => totalBudgetFormatted                              
  #        }        

  #   end
    
  
end