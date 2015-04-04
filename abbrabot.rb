#!/usr/bin/ruby
# -*- coding: utf-8 -*-

# abbrabot.rb
# Copyright (c) 2014 KITAJIMA, Akimasa

# This software is released under the MIT License.

include Math

#require 'rubygems'
#gem('twitter','0.9.8')
require 'pp'
require 'twitter'
require 'logger'
require 'fileutils'
require 'date'
require 'json'
require 'net/http'
require 'kconv'
require 'open-uri'
require "microsoft_translator"
#require 'babelphish'
#require 'easy_translate'
require 'cgi'
require 'erb'
require 'rss'
require 'nokogiri'
# ログファイル名
LOG_FILE = File.expand_path "./abbrabot.log"
def write_log msg
  if $DEBUG
    pp msg
  else
    log = Logger.new LOG_FILE, "weekly"
    log.info msg
    log.close
  end
end

Already_Tweeted = "already_tweeted"
def get_cont source,item_EXP,title_EXP,abst_EXP
  rss = URI(source)
  begin
    urls = rss.read.toutf8.scan(item_EXP).flatten.map{ |x| rss.merge(x)}
  rescue
    write_log "get_cont rss read faild from #{source}: #{$!.class}: #{$!.message}"
    return false
  end
  atFile = File.open(Already_Tweeted).read
  urls.each do |x|
    unless atFile =~ Regexp.union(x.to_s)
      begin
        str = x.read.toutf8
      rescue
        write_log "get_cont faild from #{source}: #{$!.class}: #{$!.message}"
        return false
      end
      title = $1.strip if str =~ title_EXP
      abst = $1.strip if str =~ abst_EXP
      return [x.to_s,title,abst] if abst && title && (abst != "")
    end
  end
  return false  
end
def get_cont2 source,title_path,abst_path,item_path=nil
  rss = nil
  begin
    rss = RSS::Parser.parse(source)
  rescue RSS::InvalidRSSError # invalid な RSS を受け取った時
    rss = RSS::Parser.parse(source,false)
  rescue
    write_log "[FAILD] get_cont2 of rss from #{source}: #{$!.class}: #{$!.message}"
    return false
  end
  atFile = File.open(Already_Tweeted).read
  rss.items.each do |x|
    url = x.link
    unless atFile =~ Regexp.union(url)
      begin
        doc = Nokogiri::HTML(open(url))
      rescue
        write_log "[FAILD] get_cont2 from #{url} : #{$!.class}: #{$!.message}"
        next
      end
      title = (doc.search title_path)[0].content
      abst = (doc.search abst_path)[0].content
      url = (doc.search item_path)[0].to_s if item_path
      return [url,title,abst] if abst && title && (abst != "")
    end
  end
  return false
end
def get_from_arXiv source
  item_EXP = %r!"list-identifier"><a href="(.*?)"!
  abst_EXP = %r!Abstract:</span> (.*?)</blockquote>!m
  title_EXP = %r!Title:</span>(.*?)</h1>!m
  return get_cont source,item_EXP,title_EXP,abst_EXP
end
def get_from_APS source
  title_path ="#title > div > large-12 > div.panel.header-panel > div > div.medium-9.columns > h3"
  abst_path = "#article-content > section.article.open.abstract > div.content > p:nth-child(1)"
  item_path = '//*[@id="article-content"]/section[1]/div[1]/p[2]/input/@value'
  return get_cont2 source,title_path,abst_path,item_path
end
def get_from_PNAS source
  abst_path ="#p-4"
  title_path = "#article-title-1"
  return get_cont2 source, title_path, abst_path
end
def get_from_ScienceDirect source
  atFile = File.open(Already_Tweeted).read
  begin
    rss = RSS::Parser.parse(source)
  rescue
    write_log "cannot read RSS from #{source}: #{$!.class}: #{$!.message}"
    return false
  end
  rss.items.each do |item|
    next if (!item.link || atFile =~ Regexp.union(item.link) || !item.title)
    cont = item.description.split('<br>')[3]
    next if (!cont)
    return [item.link,item.title,cont]
  end
  return false
end
#def get_from_ScienceDirect source
#  item_EXP = %r!<link>(.*?)</link>!
#  title_EXP = %r!<div class="articleTitle">(.*?)</div>!m
#  abst_EXP = %r!<h3 class="h3">Abstract</h3><a name=".+?"></a><p>(.*?)</p>!m
#  doi_EXP = %r!<a id="ddDoi" href="(.*?)"!
#  rss = URI(source)
#  begin
#    urls = rss.read.toutf8.scan(item_EXP).flatten.map{ |x| CGI.unescapeHTML(x)}
#  rescue
#    write_log "to get content from #{source} is failed"
#    return false
#  end
#  atFile = File.open(Already_Tweeted).read
#  urls.each do |x|
#    next unless x =~ %r!http://www.sciencedirect.com/science!
#    begin
#      str = URI(x).read.toutf8
#    rescue
#      write_log "to get content from #{x} is failed"
#      next
#    end
#    doi = str[doi_EXP,1].strip
#    next if atFile =~ Regexp.union(doi)
#    title = $1.strip if str =~ title_EXP
#    abst = $1.strip if str =~ abst_EXP
#    if abst && title
#      return [doi,title,abst] unless (abst == "" || abst =~ /Abstract not available/ || title == abst)
#    end
#  end
#  return false
#end
def get_from_IOP source
  atFile = File.open(Already_Tweeted).read
  begin
    rss = RSS::Parser.parse(source,false)
  rescue
    write_log "cannot read RSS from #{source}: #{$!.class}: #{$!.message}"
    return false
  end
  rss.items.each do |item|
    next if atFile =~ Regexp.union(item.link)
    return [item.link,item.title,item.description.gsub("\r\n",' ')]
  end
  return false
end
#def get_from_IOP source
#  item_EXP = %r!<rdf:li resource="(.*?)" />!
#  title_EXP = %r!<title>(.*?)</title>!m
#  abst_EXP = %r!<description>(.*?)</description>!m
#  begin
#    rss = URI(source).read
#  rescue
#    write_log "scanning rss: #{source} is failed"
#    return false
#  end
#  urls = rss.toutf8.scan(item_EXP).flatten
#  atFile = File.open(Already_Tweeted).read
#  urls.each do |x|
#    unless atFile =~ Regexp.union(x)
#      cont_EXP = %r!<item rdf:about="#{Regexp.escape x}">(.*?)</item>!m
#      p cont_EXP if $DEBUG
#      str = $1 if rss =~ cont_EXP
#      if str
#        title = $1 if str =~ title_EXP
#        abst = $1 if str =~ abst_EXP
#        return [x,title,abst].map{ |y| CGI.unescapeHTML y} if abst && title && (abst != "")
#      end
#    end
#  end
#  return false
#  # abst_EXP = %r!<dd id="articleAbsctract">.*?<P>(.*?)</P>!im
#  # return get_cont source,item_EXP,title_EXP,abst_EXP
#end
def get_from_PLOS source
  atFile = File.open(Already_Tweeted).read
  begin
    rss = RSS::Parser.parse(source)
  rescue
    write_log "cannot read RSS from #{source}: #{$!.class}: #{$!.message}"
    return false
  end
  rss.items.each do |item|
    link = item.link.href
    next if atFile =~ Regexp.union(link)
    return [link,item.title.content,item.content.content.gsub(/\A<p>by.*?<\/p>/,"").strip]
  end
end

class String
  def unescapeHTML
    str = CGI.unescapeHTML(self)
    str = str.gsub('&#8212',' ー ')
    str = str.gsub(/&#\d+{1,4};/,' ')
    return str
  end
  def delHTMLtag
    return self.gsub %r!</?.*?>!,""
  end
  def abbr
    ret = self.gsub(/([ァ-ン])([ァ-ンー]+)/){$1 + $2.gsub(/[ァ-オンャュョッ]/,"") }
    ret.gsub!(/[ぁ-んー\n\r性的我々$]/,"")
    ret.gsub!(/([[:punct:]（）\s])[[:punct:]]+/,'\1')
    ret.gsub!(/([[:alnum:]])\s/,'\1') # アルファベット間以外のスペースを除去
    ret.gsub!(/\s([[:alnum:]])/,'\1')
    ret.gsub!(/^[[:punct:]\s]*/,"") # 
    ret.gsub!(/[[:punct:]\s]*$/,"")
    return ret
  end
  def to_ja(translator)
    puts 'THE INPUT STRING IS: ' + self if $DEBUG
    # Microsoft Translator
    begin
      return translator.translate(self,"en","ja","text/html")
    rescue
      puts "ERR[#{$!}]: Wait #{300} seconds."
      p $!
      sleep $DEBUG ? 10 : 300 ;
      retry
    end
    
    #str = self.size > 1000 ? self[/\A(.{1000})/,1] : self
    #return Babelphish::Translator.translate(str,'ja')
    ## Exite翻訳
    # if Net::HTTP.post_form(URI.parse('http://www.excite.co.jp/world/english/'),{ "before" => str}).body =~ %r!<textarea id="after".*?>(.*)</textarea>!m
    #   puts 'THE OUTPUT STRING IS: '+$1.toutf8 if $DEBUG
    #   return $1.toutf8 if Net::HTTP.post_form(URI.parse('http://www.excite.co.jp/world/english/'),{ "before" => str}).body =~ %r!<textarea id="after".*?>(.*)</textarea>!m
    # end
    # return nil
  end
end
def mkMessage content,url_length,translator
  pp content if $DEBUG
  pp "URL LENGTH: #{ url_length }" if $DEBUG
  content.map!{ |x| x.gsub(/[\n\r]/,' ')}
  #url = bit_ly content[0]
  url = content[0]
  title = (content[1].unescapeHTML.delHTMLtag).unescapeHTML.to_ja(translator).unescapeHTML.abbr
  abst = (content[2].unescapeHTML.delHTMLtag).unescapeHTML.split("\n").map{ |x| x.strip}.join(' ').to_ja(translator)
  #title = CGI.unescapeHTML(CGI.unescapeHTML(content[1].delHTMLtag).to_ja.abbr)
  #abst = CGI.unescapeHTML(content[2].delHTMLtag).to_ja
  if abst =~ /。/
    $'.strip!
    abst = $' if $'.size>0
  end
  pp "TITLE: " + title if $DEBUG
  pp "ABST: " + abst.unescapeHTML if $DEBUG
  abst = abst.unescapeHTML.abbr
  abst.strip!
  abst = abst.unescapeHTML.abbr
  pp "ABST: " + abst.unescapeHTML if $DEBUG
  return nil if abst == ""
  pp [title.size, url_length]
  abst_length = 140 - title.size - url_length - 2
  abst = abst[/\A(.{#{abst_length}})/] if abst.size > abst_length
  ret = title + " " + url + " " + abst
  p ret if $DEBUG
  return ret
end

def read_twitter_config(file)
  conf = IO.foreach(file).map(&:chomp)
  return  Twitter::REST::Client.new do |config|
    config.consumer_key = conf[0]
    config.consumer_secret = conf[1]
    config.access_token = conf[2]
    config.access_token_secret = conf[3]
  end
end

def read_microsoft_translator_config(file)
  conf = IO.foreach(file).map(&:chomp)
  return MicrosoftTranslator::Client.new(conf[0], conf[1])
end

if __FILE__ == $0
  exit 1 unless ARGV[0]
  client = read_twitter_config(ARGV[0])
  exit 1 unless client
  exit 1 unless ARGV[1]
  translator = read_microsoft_translator_config(ARGV[1])
  source_PLOS = ['http://www.plosone.org/article/feed/search?unformattedQuery=subject%3A%22Computational+biology%22&sort=Date%2C+newest+first','http://www.plosone.org/article/feed/search?unformattedQuery=subject%3A%22Theoretical+biology%22&sort=Date%2C+newest+first','http://www.plosone.org/article/feed/search?unformattedQuery=subject%3A%22Artificial+intelligence%22&sort=Date%2C+newest+first','http://www.plosone.org/taxonomy/browse/physics']
  source_PRL = ['http://feeds.aps.org/rss/tocsec/PRL-SoftMatterBiologicalandInterdisciplinaryPhysics.xml']
  source_PRE = ['http://feeds.aps.org/rss/tocsec/PRE-Biologicalphysics.xml',
                'http://feeds.aps.org/rss/tocsec/PRE-Statisticalphysics.xml',
                'http://feeds.aps.org/rss/tocsec/PRE-Interdisciplinaryphysics.xml',
                'http://feeds.aps.org/rss/tocsec/PRE-Chaosandpatternformation.xml',
                'http://feeds.aps.org/rss/tocsec/PRE-rapids.xml']
  source_PhysicaD = ['http://rss.sciencedirect.com/publication/science/5537']
  source_PhysicsLettersA = ['http://rss.sciencedirect.com/publication/science/5538']
  source_EPL = ['http://iopscience.iop.org/0295-5075/?rss=1']
  source_arXiv_qBio = ['http://www.arxiv.org/list/q-bio/pastweek?show=100']
  source_arXiv_nlin = ['http://www.arxiv.org/list/nlin.CG/pastweek?show=100',
                       'http://www.arxiv.org/list/nlin.AO/pastweek?show=100',
                       'http://www.arxiv.org/list/nlin.CD/pastweek?show=100']
  source_arXiv_condMat = ['http://www.arxiv.org/list/cond-mat.dis-nn/pastweek?show=100',
                          'http://www.arxiv.org/list/cond-mat.other/pastweek?show=100',
                          'http://www.arxiv.org/list/cond-mat.stat-mech/pastweek?show=100']
  source_arXiv = source_arXiv_qBio + source_arXiv_nlin + source_arXiv_condMat
  source_PNAS_Bio = ['http://www.pnas.org/rss/Biophysics_and_Computational_Biology.xml',
                     'http://www.pnas.org/rss/Evolution.xml',
                     #'http://www.pnas.org/rss/Systems_Biology.xml',
                     'http://www.pnas.org/rss/Ecology.xml',
                    'http://www.pnas.org/rss/Genetics.xml',
                    'http://www.pnas.org/rss/Immunology.xml',
                    'http://www.pnas.org/rss/Population_Biology.xml']
  source_PNAS_Phys = ['http://www.pnas.org/rss/Applied_Physical_Sciences.xml',
                      'http://www.pnas.org/rss/Computer_Sciences.xml',
                      'http://www.pnas.org/rss/Physics.xml']
  url_length = nil
  while true
    now = Time.now
    url_length_now = client.configuration.short_url_length if (now.hour == 8 && now.min < 30) || !url_length
    if url_length_now != url_length
      p "url_length: #{ url_length_now }"
      #url_length_now = url_length
      url_length = url_length_now
    end
    if $DEBUG || (now.wday.between? 1,6) && (now.hour.between? 8,19)
      sources = [source_PRL,source_PRE,
                 source_EPL,
                 source_PhysicaD,source_PhysicsLettersA,
                 source_PNAS_Bio,source_PNAS_Phys,
                 source_PLOS
                ].shuffle << source_arXiv
      sources = [source_PLOS] if $DEBUG
      cont = false
      sources.each do |source|
        source.shuffle.each do |x|
          write_log x
          if x =~ /feeds\.aps\.org/
            cont = get_from_APS x
          elsif x =~ /sciencedirect\.com/
            cont = get_from_ScienceDirect x
          elsif x =~ /iop\.org/
            cont = get_from_IOP x
          elsif x =~ /arxiv\.org/
            cont = get_from_arXiv x
          elsif x=~ /pnas\.org/
            cont = get_from_PNAS x
          elsif x=~ /plosone\.org/
            p x if $DEBUG
            cont = get_from_PLOS x
          end
          break if cont
        end
        break if cont
      end
      if cont
        write_log cont[0] unless $DEBUG
        msg = mkMessage(cont,url_length,translator)
        if $DEBUG
          p msg 
        else
          unless msg
            write_log "CANNOT MAKE MSG: "+cont[0]
          end
          while msg
            begin
              client.update msg unless $DEBUG
            rescue
              if $!.to_s == "Status is over 140 characters."
                msg = msg[0...-1]
                retry
              end
              puts "ERR[#{$!}]: Wait #{300} seconds."
              p $!
              puts "MSG: #{msg}"
              sleep $DEBUG ? 10 : 300 ;
              next
            end
            write_log msg
            msg = nil
          end
          File.open(Already_Tweeted,"a"){ |file| file.puts cont[0] }
        end
      end
    end
    sleep $DEBUG ? 10 : 1800
  end
end
