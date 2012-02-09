#!/opt/local/bin/ruby1.9
require "rubygems"
#require 'URI'
require 'net/http'
require 'rexml/document'
module Skanetrafiken
  $point_indexes = [:stop, :address, :poi, :unknown]
  $point_string_totype ={ "STOP_AREA" => :stop, "ADDRESS" => :address, "POI" => :poi, "UNKNOWN" => :unknown}
  
  class Point
    attr_reader :name, :id, :type
    def initialize(name,id,type)
      @name=name
      @id=id
      @type=type
    end
    def ==(another_point)
      self.name == another_point.name && self.id == another_point.id && self.type == another_point.type
    end
    def render()
        idx = $point_indexes.index(@type)
       return "#{@name}|#{@id}|#{idx}"
    end    
  end
  
  class UriHelper
    def parameters_from_hash(hash)
      return hash.map{ |key,value| 
            "#{key.to_s}=#{URI.escape(value.to_s)}" 
        }.join("&")
    end
  end
  
  class GetJourney
    def initialize()
      @uri = UriHelper.new
    end
    def render_url(pointFrom,pointTo,lastStart)
      lastStartText = lastStart.strftime("%Y-%m-%d %H:%M")
      to = pointTo.render()
      from = pointFrom.render()
      parameters = {
        :cmdaction =>:next,
        :selPointFr =>pointFrom.render(),
        :selPointTo =>pointTo.render(),
        :LastStart =>lastStartText
      }
      return "http://www.labs.skanetrafiken.se/v2.2/resultspage.asp?" + @uri.parameters_from_hash(parameters)
    end
    
    def get_times(html)
        doc = REXML::Document.new(html)
        el = []
        v = doc.elements["soap:Envelope/soap:Body/GetJourneyResponse/GetJourneyResult/Journeys"]
        v.elements.each("Journey") { |j|
            el.push(j.elements["DepDateTime"].text)
        }
        return el
    end
  end
  
  class QueryStation
    def initialize()
    end
    def render_url(name)
      return "http://www.labs.skanetrafiken.se/v2.2/querystation.asp?inpPointfr=#{URI.escape(name)}"
    end
    def get_stations(html)
        doc = REXML::Document.new(html)
        el = []
        v = doc.elements["soap:Envelope/soap:Body/GetStartEndPointResponse/GetStartEndPointResult/StartPoints"]
        v.elements.each("Point") { |j|
            el.push(Point.new(
              j.elements["Name"].text,
              j.elements["Id"].text,
              $point_string_totype[j.elements["Type"].text]
            ))
        }
        return el
    end
  end

  $properties_line = {:name=>'Name',:no=>'No',:journey_date_time=>'JourneyDateTime',:is_timing_point=>'IsTimingPoint',\
    :stop_point=>'StopPoint',:line_type_id=>'LineTypeId',:line_type_id=>'LineTypeId',:line_type_name=>'LineTypeName',\
    :towards=>'Towards'}
  class Line
    attr_reader :name,:no,:journey_date_time,:is_timing_point,\
      :stop_point,:line_type_id,:line_type_id,:line_type_name,\
      :towards
    def initialize dic
      $properties_line.each{ |key,value|
         val = dic[key]
         instance_variable_set("@#{key.to_s}", val)
      }
      #puts @name
      #puts dic.map{ |k,v| "#{k}: #{v}" }.join('; ')
    end
    def ==(another)
      return $properties_line.map{ |key,value|
        k = "@#{key.to_s}"
        instance_variable_get(k) == another.instance_variable_get(k)
      }.inject(true){ |result, element| result and element}
    end
    def to_s
      a = []
      $properties_line.each{ |key,value|
        val = instance_variable_get("@#{key.to_s}")
        a.push(":#{key.to_s}=> '#{val}'")
      }
      return a.join(", ")
    end
  end
  class GetDepartureArrival
    
    def render_url(point)
      return "http://www.labs.skanetrafiken.se/v2.2/stationresults.asp?selPointFrKey=#{point.id}"
    end
    
    def get_lines(html)
      doc = REXML::Document.new(html)
      el = []
      v = doc.elements["soap:Envelope/soap:Body/GetDepartureArrivalResponse/GetDepartureArrivalResult/Lines"]
      v.elements.each("Line") { |j|
        dic = {}
        $properties_line.each{ |key,value|
          xval = j.elements[value].text
          dic[key] = xval
          #puts "#{key} = #{value} = #{xval}"
        }
        #puts dic.map{ |k,v| "#{k}, #{v}" }.join('; ')
        el.push(Line.new(dic))
      }
      return el
    end
  end

  require "crack"
  require "json"

  class XmlToJson
    def convert(xml)
      return Crack::XML.parse(xml).to_json
    end
  end
end
