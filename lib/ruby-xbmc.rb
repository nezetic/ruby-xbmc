#!/usr/bin/env ruby

=begin
    ruby-xbmc
    
    ruby-xbmc is a ruby wrapper for the XBMC Web Server HTTP API.
    
    It provides a remote access to any XBMC running on the local network, 
    in a simple way (methods follow the ones from XBMC API).
    
    
    Example:
    
    irb(main):001:0> xbmc = XBMC::XBMC.new(hostname, port, user, pass)
    => #<XBMC::XBMC:0x1128e7c>
    
    irb(main):002:0> pp xbmc.GetMediaLocation("music")
    [{"name"=>"Jazz", "type"=>"1", "path"=>"/mnt/data/Music/Jazz/"},
     {"name"=>"Electro", "type"=>"1", "path"=>"/mnt/data/Music/Electro/"},
     {"name"=>"Metal", "type"=>"1", "path"=>"/mnt/data/Music/Metal/"},
     {"name"=>"Last.fm", "type"=>"1", "path"=>"lastfm://"}]
    
    
    
    Copyright (C) 2009 Cedric TESSIER
    
    Contact: nezetic.info

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
=end

begin
    require 'rubygems'
rescue LoadError
end

require 'iconv'
require 'uri'
require 'open-uri'
require 'hpricot'

class Object 
    def caller_method
        caller[1] =~ /`([^']*)'/ and $1
    end
end

class Array
    def to_hash(keys)
        return nil if(keys.length != self.length)
        Hash[*keys.zip(self).flatten]
    end
end

class String
    def transliterate
        Iconv.iconv('ASCII//IGNORE//TRANSLIT', 'UTF-8', self).to_s
    rescue
        self
    end
end

# Module for the library
#
#=Usage example
# First, we need to create the link between us and XBMC:
#
# xbmc = XBMC::XBMC.new(hostname, port, user, pass)
#
# then, we can do a lot of things, following XBMC API.
#
#==Set current XBMC Volume
#  xbmc.SetVolume(95)
#==Get currently playing file data
#  xbmc.GetCurrentlyPlaying
#==Get a files list from music library, with insertion dates
#  xbmc.GetMediaLocation("music", "/mnt/data/Music/Jazz/", true)
#==Retrieve playlist contents
#  xbmc.GetPlaylistContents
#==Get some system information
#  xbmc.GetSystemInfoByName("weather.location","weather.temperature")
#
module XBMC
    #User Agent Name
    NAME        = 'Ruby/XBMC'
    #Library Version
    VERSION     = '0.1'
    #Complete User-Agent
    USER_AGENT  = "%s %s" % [NAME, VERSION]
    # scheme used in HTTP transfers (http/https)
    SCHEME      = "http"
    # XBMC Command API
    CMDPATH     = "/xbmcCmds/xbmcHttp?command="

    MUSIC_PLAYLIST  = 0
    VIDEO_PLAYLIST  = 1

    TYPE_DIRECTORY  = 1
    TYPE_FILE	    = 0

    #Error class when not authenticated
    class XBMC::UnauthenticatedError < StandardError
        def initialize(m=nil)
            super(m.nil? ? "You are not connected (no user/password)": m)
        end             
    end

    #Error class when password and user mismatched
    class XBMC::WrongCredentialsError < XBMC::UnauthenticatedError
        def initialize()
            super("User / password mismatched")
        end             
    end

    #Connection class used to specify credentials and proxy settings
    class Connection
        #network hostname
        attr_accessor :host
        #network port
        attr_accessor :port
        #username
        attr_accessor :user
        #password
        attr_accessor :password

        #proxy url eg. http://user:pass@proxy:8080
        attr_writer :proxy

        def initialize(host, port=nil, user=nil, pass=nil)
            @host=host
            @port=port
            @user=user
            @password=pass
        end

        #proxy getter
        def proxy
            return @proxy unless @proxy.nil?
            ENV["proxy"]
        end

        def exec(command) #:nodoc:
            command.rstrip!
            command += "()" if command[-1,1] != ")"
            url = SCHEME + "://" + host + ":" + port + CMDPATH + command

            begin
                return open(url,"r",http_opts)
            rescue OpenURI::HTTPError => e 
                if e.io.status.first.to_i == 401
                    raise (user.nil? ? UnauthenticatedError.new  : WrongCredentialsError.new )
                end
                raise e
            end
        end	

        protected
        def http_opts #:nodoc:
            ret={}
            ret[:http_basic_authentication]=[user,password] unless user.nil?
            ret[:proxy]=proxy
            ret["User-Agent"]=USER_AGENT
            return ret
        end

    end

    class XBMC
        attr_accessor :error

        ##### XBMC API
        # Commands that Retrieve Information
        def GetMediaLocation(type, path=nil, showdate=false)
            if(showdate)
                parse_asdictlist(cmd(with_args(type, path, "showdate")), ["name", "path", "type", "date"]) 
            else
                parse_asdictlist(cmd(with_args(type, path)), ["name", "path", "type"]) 
            end
        end

        def GetShares(type)
            parse_asdictlist(cmd(with_args(type)), ["name", "path"]) 
        end

        def GetCurrentPlaylist
            parse(cmd())
        end

        def GetCurrentlyPlaying
            song = parse_asdict(cmd())
            return nil if(song.length <= 1)
            song
        end

        def GetCurrentSlide
            parse(cmd())
        end

        def GetDirectory(directory, mask=" ", showdate=false)
            if(showdate)
                parse_asdictlist(cmd(with_args(directory, mask, 1)), ["path", "date"])
            else
                parse_aslist(cmd(with_args(directory, mask)))
            end
        end

        def GetGuiDescription
            parse_asdict(cmd())
        end

        def GetGuiSetting(type, name)
            parse(cmd(with_args(type, name)))
        end

        def GetGuiStatus
            parse_asdict(cmd())
        end

        def GetMovieDetails
            puts "Not implemented"
        end

        def GetPercentage
            parse(cmd())
        end

        def GetPlaylistContents(playlist=nil)
            parse_aslist(cmd(with_args(playlist)))
        end

        def GetPlaylistLength(playlist=nil)
            parse(cmd(with_args(playlist)))
        end

        def GetPlaylistSong(position=nil)
            parse(cmd(with_args(position)))
        end

        def GetPlaySpeed
            parse(cmd())
        end

        def GetMusicLabel
            puts "Not implemented"
        end

        def GetRecordStatus
            puts "Not implemented"
        end

        def GetVideoLabel
            puts "Not implemented"
        end

        def GetSlideshowContents
            parse_aslist(cmd())
        end

        def GetSystemInfo(*args)
            parse_aslist(cmd(with_args(args)))
        end

        def GetSystemInfoByName(*args)
            parse_aslist(cmd(with_args(args)))
        end

        def GetTagFromFilename(fullpath)
            parse_asdict(cmd(with_args(fullpath)))
        end

        def GetThumbFilename
            puts "Not implemented"
        end

        def GetVolume
            parse(cmd())
        end

        def GetLogLevel
            parse(cmd())
        end

        def QueryMusicDatabase
            puts "Not implemented"
        end

        def QueryVideoDatabase
            puts "Not implemented"
        end

        # Commands that Modify Settings

        def AddToPlayList(media, playlist=nil, mask=nil, recursive=true)
            if(recursive == true)
                recursive = 1
            else
                recursive = 0
            end
            success?(parse(cmd(with_args(media, playlist, mask, recursive))))
        end

        def AddToSlideshow(media, mask="[pictures]", recursive=true)
            if(recursive == true)
                recursive = 1
            else
                recursive = 0
            end
            success?(parse(cmd(with_args(media, mask, recursive))))
        end

        def ClearPlayList(playlist=nil)
            success?(parse(cmd(with_args(playlist))))
        end

        def ClearSlideshow
            success?(parse(cmd()))
        end

        def Mute
            success?(parse(cmd()))
        end

        def RemoveFromPlaylist(item, playlist=nil)
            success?(parse(cmd(with_args(item, playlist))))
        end

        def SeekPercentage(percentage)
            success?(parse(cmd(with_args(percentage))))
        end

        def SeekPercentageRelative(percentage)
            success?(parse(cmd(with_args(percentage))))
        end

        def SetCurrentPlaylist(playlist)
            success?(parse(cmd(with_args(playlist))))
        end

        def SetGUISetting(type, name, value)
            success?(parse(cmd(with_args(type, name, value))))
        end

        def SetPlaylistSong(position)
            success?(parse(cmd(with_args(position))))
        end

        def SetPlaySpeed(speed)
            success?(parse(cmd(with_args(speed))))
        end

        def SlideshowSelect(filename)
            success?(parse(cmd(with_args(filename))))
        end

        def SetVolume(volume)
            success?(parse(cmd(with_args(volume))))
        end

        def SetLogLevel(level)
            success?(parse(cmd(with_args(level))))
        end

        def SetAutoGetPictureThumbs(boolean=true)
            success?(parse(cmd(with_args(boolean))))            
        end

        # Commands that Generate Actions

        def Action(code) # Sends a raw Action ID (see key.h)
            success?(parse(cmd(with_args(code))))
        end

        def Exit
            success?(parse(cmd()))
        end

        def KeyRepeat(rate)
            success?(parse(cmd(with_args(rate))))
        end

        def Move(deltaX, deltaY)
            success?(parse(cmd(with_args(deltaX, deltaY))))
        end

        def Pause
            success?(parse(cmd()))
        end

        def PlayListNext
            success?(parse(cmd()))
        end

        def PlayListPrev
            success?(parse(cmd()))
        end

        def PlayNext
            success?(parse(cmd()))
        end

        def PlayPrev
            success?(parse(cmd()))
        end

        def PlaySlideshow(directory=nil, recursive=true)
            success?(parse(cmd(with_args(directory, recursive))))
        end

        def PlayFile(filename, playlist=nil)        
            success?(parse(cmd(with_args(filename, playlist))))
        end

        def Reset
            success?(parse(cmd()))
        end

        def Restart
            success?(parse(cmd()))
        end

        def RestartApp
            success?(parse(cmd()))
        end

        def Rotate
            success?(parse(cmd()))
        end

        def SendKey(buttoncode)
            success?(parse(cmd(with_args(buttoncode))))
        end

        def ShowPicture(filename)        
            success?(parse(cmd(with_args(filename))))
        end

        def Shutdown
            success?(parse(cmd()))
        end

        def SpinDownHardDisk
            success?(parse(cmd()))
        end

        def Stop
            success?(parse(cmd()))
        end

        def TakeScreenshot(width=300, height=200, quality=90, rotation=0, download=true, filename="xbmc-screen.jpg", flash=true, imgtag=false)
            if(imgtag)
                imgtag = "imgtag"
            else
                imgtag = nil
            end
            parse(cmd(with_args(filename, flash, rotation, width, height, quality, download, imgtag)))
        end

        def Zoom(zoom)
            success?(parse(cmd(with_args(zoom))))
        end

        ##### END XBMC API

        def initialize(host, port=nil, user=nil, pass=nil)
            @@connection = Connection.new(host, port, user, pass)
        end

        def error?
            not error.nil?
        end

        def print_error
            $stderr.puts "Error: " + @error if @error != nil
        end

        def host
            @@connection.host
        end

        def port
            @@connection.port
        end

        # private members
        private

        def with_args(*args)
            args.flatten! if args.length == 1
            command = self.caller_method
            command += "("
            cmdargs = ""
            args.each {|arg| cmdargs += (";" + (URI.escape(arg.to_s, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]")))) unless arg.nil? }
            cmdargs = cmdargs[1..-1]
            command += cmdargs unless cmdargs.nil?
            command += ")"
        end

        def cmd(command=nil)
            command = self.caller_method if command.nil?
            response = @@connection.exec(command)
        end

        def success?(res)
            (not error? and not res.nil? and res == "OK") 
        end

        def parse_resp(response)
            doc = Hpricot(response)
            list = (doc/"li")
            if(list.length > 0)
                text = list.inner_text
                if(text[0,5] == "Error")
                    idx = text.index(':')
                    if(idx != nil)
                        @error = text[(idx+2)..-1]
                    else
                        @error = "Unknown error"
                    end
                else
                    @error = nil
                end
            else  # file download (screenshot)
                return doc
            end
            list
        end 

        def parse(response)
            resp = parse_resp(response).inner_text.transliterate
            return "" if error?
            resp	
        end

        def parse_aslist(response)
            list = []
            parse_resp(response).each {|item| list.push(item.inner_text.transliterate.chomp)}
            return [] if error?
            list
        end

        def parse_asdictlist(response, keys)
            list = []
            parse_aslist(response).each {|item| list.push((item.split(';').collect {|x| x.transliterate.chomp.rstrip}).to_hash(keys) )}
            return [] if error?
            list
        end

        def parse_asdict(response)
            dict = {}
            resp = parse_resp(response)
            return dict if error?
            resp.each {|item|
                item = item.inner_text.transliterate
                idx = item.index(':')
                next if item == nil
                key = item[0..idx-1]
                value = item[idx+1..-1].chomp
                dict[key]=value
            }
            dict
        end

    end

end
