#!/usr/bin/env ruby

# -------------------------------------------------------------------------- #
# Copyright 2002-2024, OpenNebula Project, OpenNebula Systems                #
#                                                                            #
# Licensed under the Apache License, Version 2.0 (the "License"); you may    #
# not use this file except in compliance with the License. You may obtain    #
# a copy of the License at                                                   #
#                                                                            #
# http://www.apache.org/licenses/LICENSE-2.0                                 #
#                                                                            #
# Unless required by applicable law or agreed to in writing, software        #
# distributed under the License is distributed on an "AS IS" BASIS,          #
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.   #
# See the License for the specific language governing permissions and        #
# limitations under the License.                                             #
#--------------------------------------------------------------------------- #

require 'etc'
require 'base64'
require 'zlib'
require 'fileutils'

module CloudInit

    DEFAULT_PERMS = '0644'
    DEFAULT_OWNER = 'root:root'
    TEXT_PLAIN_ENC = 'text/plain'
    DEFAULT_DEFER = false
    DEFAULT_APPEND = false

    ##
    # WriteFile class implements the write_file cloud-config directive.
    ##
    class WriteFile

        attr_accessor :path, :content, :source, :owner, :permissions, :encoding, :append, :defer

        def initialize(path:, content: '', source: [], owner: DEFAULT_OWNER,
                       permissions: DEFAULT_PERMS, encoding: TEXT_PLAIN_ENC,
                       append: DEFAULT_APPEND, defer: DEFAULT_DEFER)
            @path = path
            @content = content
            @source = source
            @owner = owner
            @permissions = permissions
            @encoding = encoding
            @append = append
            @defer = defer
        end

        def exec
            # TODO: Defer execution
            return if @defer

            begin
                CloudInit::Logger.info(
                    "[writeFile] writing file [#{@permissions} #{@owner} #{@path}]"
                )

                uid, gid = uid_and_guid_by_owner
                omode = @append ? 'ab' : 'wb'
                @content = read_url_or_decode
                @path = File.absolute_path(@path)

                FileUtils.mkdir_p(File.dirname(@path))
                File.open(@path, omode) do |file|
                    file.write(@content)
                    file.chmod(decode_perms)
                    file.chown(uid, gid)
                end
            rescue Errno::EACCES
                CloudInit::Logger.error(
                    "[writeFile] Insufficient permissions [#{@permissions} #{@owner} #{@path}]"
                )
            rescue Errno::ENOENT
                CloudInit::Logger.error(
                    "[writeFile] Parent directory missing [#{@permissions} #{@owner} #{@path}]"
                )
            rescue StandardError => e
                CloudInit::Logger.error(
                    "[writeFile] Unexpected error: #{e.message}\n#{e.backtrace.join("\n")}"
                )
            end
        end

        def self.from_map(data_map)
            unless data_map.is_a?(Hash)
                raise 'WriteFile.from_map must be called with a Hash as an argument'
            end

            WriteFile.new(**data_map)
        end

        def read_url_or_decode(ssl_details: nil)
            url = @source.is_a?(Hash) ? @source['uri'] : nil
            use_url = !url.nil?

            return '' if @content.nil? && !use_url

            result = nil
            if use_url
                begin
                    result = UrlHelper.read_file_or_url(
                        url,
                        :headers => @source['headers'],
                        :ssl_details => ssl_details
                    ).contents
                rescue StandardError => e
                    CloudInit::Logger.error(
                        "Failed to retrieve contents from source '#{url}'; \n
                         falling back to content: #{e.message}"
                    )
                    use_url = false
                end
            end

            if @content && !use_url
                extractions = canonicalize_extraction
                result = extract_contents(extractions)
            end

            result
        end

        def decode_perms
            begin
                case @permissions
                when Integer, Float
                    @permissions.to_i
                else
                    @permissions.to_s.to_i(8)
                end
            rescue ArgumentError, TypeError
                CloudInit::Logger.warn(
                    'Undecodable permissions, returning default'
                )
                DEFAULT_PERMS.to_i(8)
            end
        end

        def uid_and_guid_by_owner
            user, group = @owner.split(':')

            begin
                return Etc.getpwnam(user).uid, Etc.getgrnam(group).gid
            rescue ArgumentError
                CloudInit::Logger.error(
                    "[writeFile] Owner does not exist [#{@permissions} #{@owner} #{@path}]"
                )
            end
        end

        def canonicalize_extraction
            encoding_type = @encoding.downcase.strip

            case encoding_type
            when 'gz', 'gzip'
                ['application/x-gzip']
            when 'gz+base64', 'gzip+base64', 'gz+b64', 'gzip+b64'
                ['application/base64', 'application/x-gzip']
            when 'b64', 'base64'
                ['application/base64']
            when TEXT_PLAIN_ENC
                [TEXT_PLAIN_ENC]
            else
                CloudInit::Logger.warn(
                    "Unknown encoding type #{encoding_type}, assuming #{TEXT_PLAIN_ENC}"
                )
                [TEXT_PLAIN_ENC]
            end
        end

        def extract_contents(extraction_types)
            result = @content

            extraction_types.each do |t|
                case t
                when 'application/x-gzip'
                    result = Zlib::Inflate.inflate(result)
                when 'application/base64'
                    result = Base64.decode64(result)
                when TEXT_PLAIN_ENC
                    # No transformation needed
                end
            end
            result
        end

    end

end
