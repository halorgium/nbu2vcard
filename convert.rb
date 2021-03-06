#!/usr/bin/env ruby

require 'logger'
require 'fileutils'
LOGGER = Logger.new($stderr)

class NokiaFile
  FIRST_BITS  = /[\240\[\]{};\w>\306:\\\210\234`\316\201?\220^\215"\307\267<\202]/
  SECOND_BITS = /[\000\021]/

  def initialize(filename)
    @filename = filename
  end
  attr_reader :filename

  def content
    @content ||= File.read(filename)
  rescue Errno::ENOENT
    abort "data file not found"
  end

  def parts
    LOGGER.info "content size: #{content.size}" unless @parts
    @parts ||= content.split(/\020\000\000\000\001\000\000\000#{FIRST_BITS}#{SECOND_BITS}\000\000/)
  end

  def vcards
    @vcards ||= begin
      LOGGER.info "parts size: #{parts.size}" unless @vcards
      parts.map do |part|
        VCard.new(part)
      end
    end
  end

  def vcards_with_more_than_one
    vcards.select do |vcard|
      vcard.vcard_count > 1
    end
  end

  def write
    FileUtils.mkdir(data_dir)
    vcards.each_with_index do |vcard,i|
      vcard.write("#{data_dir}/#{i}.vcf")
    end
  end

  def data_dir
    @data_dir ||= File.expand_path(File.dirname(__FILE__)) + "/output/#{Time.now.to_i}"
  end
end

class VCard
  def initialize(part)
    @part = part
  end
  attr_reader :part

  def vcard_count
    part.scan("BEGIN:VCARD").size
  end

  def write(filename)
    File.open(filename, "w") do |f|
      f.write part
    end
  end
end

require 'pp'

filename = ARGV.first || abort("provide a .nbu data file to parse")
nf = NokiaFile.new(filename)
bad = nf.vcards_with_more_than_one
if bad.any?
  LOGGER.error "there are #{bad.size} vcards with more than one inside :("
  LOGGER.error "here is the first"
  pp bad.first.part.split(/\n/)
else
  LOGGER.info "writing vcards to #{nf.data_dir}"
  nf.write
end
