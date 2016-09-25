#!/usr/bin/env ruby
require "bundler/setup"
require "net/http"
require "promise.rb"
require "nokogiri"
require "pry"
require "fileutils"

module TrackExplorer
  class HttpRequest < Promise
    THREADS = {}.compare_by_identity

    def self.get(url)
      promise = new

      THREADS[promise] = Thread.start {
        uri = URI.parse(url)
        cache_path = "#{__dir__}/cache/#{uri.host}#{uri.path}"
        if File.exist?(cache_path)
          File.read(cache_path)
        else
          http = Net::HTTP.new(uri.host, uri.port)
          response = http.get(uri.path, "Host" => uri.host)
          if response.is_a?(Net::HTTPOK)
            FileUtils.mkdir_p(File.dirname(cache_path))
            File.write(cache_path, response.body)
            response.body
          else
            raise "unexpected response: #{response.header}"
          end
        end
      }

      promise
    end

    def wait
      while pending?
        promise, thread = THREADS.shift

        begin
          promise.fulfill(thread.value)
        rescue => ex
          promise.reject(ex)
        end
      end
    end
  end

  class Track
    attr_reader :artist, :name, :uri

    def initialize(artist:, name:, uri:)
      @artist = artist
      @name = name
      @uri = uri
    end

    def ==(other)
      return false unless other.is_a?(Track)

      if uri
        uri == other.uri
      else
        [artist, name] == [other.artist, other.name]
      end
    end

    alias_method :eql?, :==

    def hash
      if uri
        uri.hash
      else
        name.hash
      end
    end
  end

  module_function

  def fetch_html(uri)
    HttpRequest.get("http://www.1001tracklists.com#{uri}").then { |html|
      Nokogiri::HTML(html)
    }
  end

  def itemprop(node, prop)
    if meta = node.css("meta[itemprop=#{prop}]").first
      meta.attr("content")
    end
  end

  def track_from_node(node)
    Track.new(
      artist: itemprop(node, "byArtist"),
      name: itemprop(node, "name"),
      uri: itemprop(node, "url"),
    )
  end

  def find_similar_tracks(root_track_uri)
    fetch_html(root_track_uri).then { |doc|
      doc.css(".tlLink a").map { |tl_link|
        tl_link.attr("href")
      }
    }.then { |tracklist_uris|
      HttpRequest.all(tracklist_uris.map { |tracklist_uri|
        fetch_html(tracklist_uri)
      })
    }.then { |documents|
      documents.flat_map { |document|
        tracks = document.css("[itemtype='http://schema.org/MusicRecording']").each_with_index.map { |node, index|
          [track_from_node(node), index]
        }

        _, root_track_index = tracks.find { |track, index|
          track.uri == root_track_uri
        }

        tracks.map { |track, index|
          distance = (index - root_track_index).abs
          score = 1 / Math.log(distance + 1)
          [track, score]
        }.to_h
      }.reduce({}) { |a, b|
        a.merge(b) { |track, score_a, score_b|
          score_a + score_b
        }
      }.sort_by { |track, score|
        -score
      }
    }
  end
end

if $0 == __FILE__
  track_slug = ARGV.shift or abort "usage: #{$0} <track-slug>"

  similar_tracks = TrackExplorer.find_similar_tracks("/track/#{track_slug}/index.html").sync

  similar_tracks.take(40).each do |track, score|
    printf("%8.2f    %s - %s\n", score, track.name, track.artist)
  end
end
