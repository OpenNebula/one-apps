require "base64"
require "init"
require 'lib/DiskResize'
require 'net/http'
require 'uri'
require 'yaml'

include DiskResize

shared_examples_for "service_Harbor" do |name, hv|
    context "simple run" do
        include_examples "context_linux", name, hv, 'vd', <<-EOT
CONTEXT=[
  NETWORK="YES",
  SSH_PUBLIC_KEY=\"$USER[SSH_PUBLIC_KEY]\",
  TOKEN="YES",
  REPORT_READY="YES"]
EOT

        it "finished appliance scripts with success" do
            cmd = @info[:vm].ssh("cat /etc/one-appliance/status")
            expect(cmd.success?).to be(true)
            expect(cmd.stdout.strip).to eq('bootstrap_success')
        end

        it "HTTPs service is working" do
            vm_ip = @info[:vm].xml['TEMPLATE/NIC[1]/IP']

            # Checking permanent redirect to HTTPS
            res = Net::HTTP.get_response(vm_ip, '/')
            expect(res.code).to eq('308')
            expect(res['location']).to include(":443")

            # Check HTTPs (self-signed) is working
            url = URI.parse(res['location'])
            http = Net::HTTP.new(url.host, url.port)
            http.use_ssl = true
            http.verify_mode = OpenSSL::SSL::VERIFY_NONE
            res = http.get(url.request_uri)
            expect(res.code).to eq('200')
            # Checking specific part of the body
            expect(res.body).to include("<title>Harbor</title>")  

        end

        it "all containers are Healthy" do
            # Bash oneliner to check if all running containers are healthy. 
            cmd = @info[:vm].ssh('all_healthy=1; container_ids=$(docker ps --format "{{.ID}}"); for container_id in $container_ids; do health=$(docker inspect --format "{{.State.Health.Status}}" "$container_id"); if [ "$health" != "healthy" ]; then return 1; fi; done; if [ $all_healthy -eq 1 ]; then return 0; fi')
            expect(cmd.success?).to be(true) # 1 => all healthy   0 => unhealthy containers present
        end

        it "has appliance YAML metadata" do
            cmd = @info[:vm].ssh("cat /etc/one-appliance/metadata")
            expect(cmd.success?).to be(true)
            expect(cmd.stdout.strip).not_to be_empty

            begin
                yaml = YAML.load(cmd.stdout)
            rescue
            end

            expect(yaml.is_a?(Hash)).to be_truthy

            ['name', 'version', 'build', 'description'].each do |key|
                expect(yaml).to have_key(key)

                #TODO: render description with MarkDown
                case key
                when 'build'
                    expect(yaml[key]).to be > 1714994808  # Mon May 06 2024 11:26:48 GMT+0000
                else
                    expect(yaml[key]).not_to be_empty
                end
            end
        end

        it "reports READY=YES via OneGate" do
            vm_ready= @info[:vm].xml['USER_TEMPLATE/READY']
            expect(vm_ready).to eq("YES")
        end

        it "can't remotely connect to PostgreSQL DB" do
            # DB should be exposed in harbor-db docker container => docker internal IP, port 5432
            cmd = SafeExec.run("nc -w2 #{@info[:vm].ip} 5432 </dev/null 2>/dev/null")
            expect(cmd.success?).to be(false)
            expect(cmd.stdout).to be_empty
        end
    end

    context "simple run with SSL" do
        include_examples "context_linux", name, hv, 'vd', <<-EOT
CONTEXT=[
  NETWORK="YES",
  SSH_PUBLIC_KEY=\"$USER[SSH_PUBLIC_KEY]\",
  ONEAPP_HARBOR_SSL_CERT="LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUZXVENDQTBHZ0F3SUJBZ0lKQVBHb2NsU0p5cVR4TUEwR0NTcUdTSWIzRFFFQkN3VUFNRUl4Q3pBSkJnTlYKQkFZVEFsaFlNUlV3RXdZRFZRUUhEQXhFWldaaGRXeDBJRU5wZEhreEhEQWFCZ05WQkFvTUUwUmxabUYxYkhRZwpRMjl0Y0dGdWVTQk1kR1F3SUJjTk1UZ3hNVEl5TVRZd056RTFXaGdQTWpJNU1qQTVNRFl4TmpBM01UVmFNRUl4CkN6QUpCZ05WQkFZVEFsaFlNUlV3RXdZRFZRUUhEQXhFWldaaGRXeDBJRU5wZEhreEhEQWFCZ05WQkFvTUUwUmwKWm1GMWJIUWdRMjl0Y0dGdWVTQk1kR1F3Z2dJaU1BMEdDU3FHU0liM0RRRUJBUVVBQTRJQ0R3QXdnZ0lLQW9JQwpBUURFSXFmNXJ6NFErMFAycjc4V2FpNU50eGtsK2RkbTBsWTFhYzVsTUtVQklCZHRTT0puVXM3MWhJS0tqbzRBCmRZMTF1TTV0Vkd3OWFWMk5FSU1pZ0haZ1VKcENXYVlzdThJOHhHdlZZUHpiRU9YdGh3TWJEMDFhamVrTjJaL3AKc0xPYWpmR3JDWkoxUzAzSUhUK3dRQ09Fb01NYVhMSDFHSHFGRkRmdUxrMTh1a0d6TEZiOVllMFZUV2FBOEN6WApkOUxONnBGdUdHYmxkbU1ORHEvMUVDZHhQQXBoMjJnNDlZbnFWR2xYYVBhbGgwRGlSdEk2eTd2ckFDb2ZGbTFnCnFZbDM3UkJvSTIwcEN1aVNkQUp2UFhYYnQvM0lVUTVEOS9jNkl0ditLbTdGZjM4QlBoZjNXYkc5N3V1NTcycW8KRGRadWhrQ01qVHYxWVRFcnU5NnpyalZrcjJxQWxIM3ZmS2JpeXN5MDJEMFRmQ2RKMVVoS01LTzJYMHpRWG0wYwpFTjl0VjUwdmVNOTdGN2ZiM0Ntc1RKeEFIcnFOSGUzelFHczZnTjlBQVBkOXBJY0tyUS93d0dZNmV0Ykc4OHV0Cm5OdXhDaEZTQVFMTFlYWURmanAvOUVjMGpiK1NDcE9ReDBpL3RrVkRJdERqNkNOZ1JFWE1lUU5aT0lDektVWEYKT2ppRFdITUtUK1BBMFVIYlpFb3BGODdPbERiNlpUaXdrNUFiNW01LzVZOWhXMWIyRlpjd2xNREFPSXQvZ0hLcQpvWEZnc3hTK3BSWFp4SlFFRlZMYVdiU3lPRTFWZXJMWXBzanFYVjh5aEFUdGRpZUs1eFBEUnZwRHVvaGFqeHloCnFuRmgwanpwcEQ2V1dicC9GSzZqZEdkRWJWR2xudDZ5SHhnQnAxbExXek5vMndJREFRQUJvMUF3VGpBZEJnTlYKSFE0RUZnUVVVSzhNdS9ESldQSGVmbFE5Ry9ub1J1VSs3YTB3SHdZRFZSMGpCQmd3Rm9BVVVLOE11L0RKV1BIZQpmbFE5Ry9ub1J1VSs3YTB3REFZRFZSMFRCQVV3QXdFQi96QU5CZ2txaGtpRzl3MEJBUXNGQUFPQ0FnRUFFdnFiCmNGcVJUNFlXNmNLSTc3aExXSk9kcEdWZmlLSUNlVzVVWVhIaWMxV2xHalZjOGk5ZkcwRGpSMy90QW1qbHcxU2MKUEFIQWo1cTJCMitjTDZKU21QYXFrZkRpQVpLeENWaEpDY1hvZHk3TWtTaVhMdUxmdWpLRVBrZjdXL0xKUjdLSQpuREs1ZldqM01wRnYweXRGRjZQb1pWZzdjMzZsL0dBUHJraG1LTW5pME15d2RndDdlTFdPMVhNVW83RWdqcXRpCjhaRTQ2Q3YwY1hzNFVhUmNtL1VLaFBkUnRrSTFrOUg2WW45US9oS0w4Y20yS1BsSklpOVFnQUtxWHRWMlcvcXIKQ0NmN0VqeXdNM0xSSGpMVXlFSE1NQmx1N2RudDg4VUlnNWRmS0dibThoMlozeWRIY0FuelFiOUszZ1NBZjJWMwpSbk53Q0JKSkplMzRKNXlBN21ibENKMUlaNHZEcGxsVkkyVWJJand1K1hpODhaSFkzaFNXOW9LR0huSEdGWHErClRQekUzY0szNW9zVHpTTVpJUVhkeXE3RjhCOG1oM2FNTTNuZWtycEdWZG04cUluQUYyWGRDTjJNekRZNHlQbUEKemNqZDFHWFRPWUtnQnZzYVNvbHpwSm4xQ2x0R01NY1FmSnFtMm1qeXpiVzdsWUZJbnZqNy9rbGRlZjA2UlRXTQpvclh0Z2F6U1dab09GVFBLVjNsSTVoUUNhUEpMbnB4RWJ6ZzNUVmIvY2tNQVM0dXFSVHcyOTlXMFAxYTU3UWthCnNnbjFqamhwNXJUSHlzcWJvd29HaU1vZzJoZHJOSnM1TzFEMzdsZU9hcVZsL0VTVi9VOEJhUnJZTzRZNzFKNFUKK2FTY2FQY0hEWjJnbm1kOU4rZFBTQWVFS1JYWlFoMlQwdFpWeDI0PQotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCg==",
  ONEAPP_HARBOR_SSL_KEY="LS0tLS1CRUdJTiBSU0EgUFJJVkFURSBLRVktLS0tLQpNSUlKS1FJQkFBS0NBZ0VBeENLbithOCtFUHREOXErL0Ztb3VUYmNaSmZuWFp0SldOV25PWlRDbEFTQVhiVWppCloxTE85WVNDaW82T0FIV05kYmpPYlZSc1BXbGRqUkNESW9CMllGQ2FRbG1tTEx2Q1BNUnIxV0Q4MnhEbDdZY0QKR3c5TldvM3BEZG1mNmJDem1vM3hxd21TZFV0TnlCMC9zRUFqaEtEREdseXg5Umg2aFJRMzdpNU5mTHBCc3l4VwovV0h0RlUxbWdQQXMxM2ZTemVxUmJoaG01WFpqRFE2djlSQW5jVHdLWWR0b09QV0o2bFJwVjJqMnBZZEE0a2JTCk9zdTc2d0FxSHhadFlLbUpkKzBRYUNOdEtRcm9rblFDYnoxMTI3Zjl5RkVPUS9mM09pTGIvaXB1eFg5L0FUNFgKOTFteHZlN3J1ZTlxcUEzV2JvWkFqSTA3OVdFeEs3dmVzNjQxWks5cWdKUjk3M3ltNHNyTXROZzlFM3duU2RWSQpTakNqdGw5TTBGNXRIQkRmYlZlZEwzalBleGUzMjl3cHJFeWNRQjY2alIzdDgwQnJPb0RmUUFEM2ZhU0hDcTBQCjhNQm1PbnJXeHZQTHJaemJzUW9SVWdFQ3kyRjJBMzQ2Zi9SSE5JMi9rZ3FUa01kSXY3WkZReUxRNCtnallFUkYKekhrRFdUaUFzeWxGeFRvNGcxaHpDay9qd05GQjIyUktLUmZPenBRMittVTRzSk9RRytadWYrV1BZVnRXOWhXWApNSlRBd0RpTGY0QnlxcUZ4WUxNVXZxVVYyY1NVQkJWUzJsbTBzamhOVlhxeTJLYkk2bDFmTW9RRTdYWW5pdWNUCncwYjZRN3FJV284Y29hcHhZZEk4NmFRK2xsbTZmeFN1bzNSblJHMVJwWjdlc2g4WUFhZFpTMXN6YU5zQ0F3RUEKQVFLQ0FnQldjNHdrd3ppUlZaOXNZYVRScFhYSmJaWlpKZG5yQ1hWVVQ5SFl5bXRBcHJ1TXdSNkNPbjdjdTA2cQo4aERuWk9rNFpZQWZzcUdQSkIxSEsyc1J6eHZlY2tpOFREV3g3QVMrc2pseHNURmpBZnpIQ01hMnE3VUY0QjFFCnJKTU85NE1DOGVQKzV0WTJlejNLb2hITGgwbmdrTmZPaStNb3pHUmN1ais0N1pIY0UyRVlMOGdjSVlqVjVlcnoKbEdtL2c2SllmemNoRndKcnpCWDIwRzJBa0dGQ1NSdXViSDV3OU5HWWh5SnprK0Y3cnJWTHg3bXNqdGJDeTZ6RgpUU1ppLy9lRzgraFNicU1UL3lucU85WkM0QTFPRHJoL0RqTkNoRTdsd2kzRHgwSlNMVk4yNGI3QW1UbCtKWXlqCnhVTDIxanFaTnZYR3ZnNGFwMzk3N25CSU5OWjFSNlpnODNnVG5OWDI1VzRGMDcrMkhtd2ZrRFhuVnZLcGlCZ0kKSjN6VXRhSVU4ODgrcngxTXA4aCtTS3Y2NlZZc3JOQjQvN1FyUytPUnZYc09RUEZRdFVUZDVZV2RSYVN6eHJVOAozajMxVFhSdDhBNlFpTVM0c0NlWExFbXJUaUtNSDh0OWhabFZXb0QwVy9GL1dRTjF4azEzZlZIYS9zOWhvU2FJCnYxdlNSOEVzTzJsUkpRL0FXeVhMS09iOU1naHRrMHlDYjRhbWxCc3lFZW8rdUVzay8za2U0MzlKVzhVRCs2OU8KZEhhU0RIMTcxLytwOXhGTk0wN242OEN6elFoeVVCdUU3MWVZNThTSU1sam1RVGRmWUxYbjRWU29PK3RXeW9uQgoxZ0hGUTBrVG5QUmo0dk9yRTlFY05aMlJLRDRncVZ4TWFuMlUwSnVWa08vOWlTdWE4UUtDQVFFQTh5SjErTTIrCm5EQ1FPWXFscXVkMTBpZ2ZOd0Z3elB0cGsyd3NXQzBvbStkVU9Qd3J0S3ZNVVdhUjd0NlZFMmRvZXM2aEwySUIKbU5FQmFFT3hNYVhtZkloRlR6Zy9zNHRVUkxMdVlTWXVOb2xIaC9DS2RVMjhmRzhGblNYV2JXQmt5T2dUT0VZVApXZk1SejhmREFKRm5TRmRaemtTQ09YTWdraW5JSEdrdTRWRmJmV2tHMFUyUWJaaG4remc4dm5UMW9xMFFFQVR2Ci9RK2puKzBGMXlUWHJUb0ROMnY0bGhGVDQxdmJFVEZhV2lUcUdWamRDRDNBNGpKM1FKMEdKTldIQ0l3Nzk5YzUKa3cxZ1NxTzNLbmw0am1uZU1GbjVDRkNOY2NVZ01NWC90TWw2Q2Y5cTF4Tm5qRzdHZnJtVWRtR2xkajQ0Uno4ZApOU0ZleE5CK2h6TjdTUUtDQVFFQXpvT0pUNnN6YVlKK0duOWRlZFlabThNVTJaWTJvMGRQQ0NUT1VaWTQwMUVzCnlTQWc2Ulh3aWl0RkN0MG1wa3hmQktRenY3VjR5dWtKZ1pCQzBUT0lnc1lOVEFRc0lrWnBKNDJIenQvOTNnaW0KTmFKNHFUdkxOUFlOcFdER0VKRXFjVzBUaHV3OHpBOGpWNUF5YjJCd0k3dnFicFdhaUg3SkhZUU55Q1lNY0ZKTwp3NVhJTkJ4QVhseHRiQjRFNTkvNFh2bnREK0hFbGp6cjA5elVxcXlhTVpLYm15QVcxUk1Fa2FITmlnUzhpYUI5CnJWVVpTWEM4WnhjZndBZUlZblRQdFBRUy9XaEw1TjJtWTRKNzlkS1lzdGNsNUd4RW9DSGVBVjFSdHFLYTduS3UKTDkrdzh2cDU4c29zb3p3VTR5UUFTeC9qcFFIbE0vbnVjcE1GMWpJL0F3S0NBUUVBaHNQbExDR3VzNWhmZU9XVwo2bUlkZG4xeXYrUjJoOGdiUHZISXFwOXRVTzBxUytQS3Zmd3o1aks2VlBMZklzQkFzMEZ4S25oaWRqZnpWYjJmCnErdFBGRnZjUHdyb2xEWjRZUlBrK2NoVitUaWlnNEVhM2VaV3dZb3dUR2k2c0Ntcjg0aGZqdU9ZdWxUMjNIclgKWmFzeTJuQkFnUXFNUEJmS1Ivb014Mkt0NzRwTzhmYVRKdFNkWjRJQXNNajlNbnhWNHZPV1lhcTY4MFFGNkJGVApHV3Q4ZUxJZE1rMFFudTIvMTlnRVYwVkoxWWw4a013bXgvaWl2ejVGeDNUQ0FReXlLbFRBc0tHRmNqTUoycFZnClk1U3M5Qk5PYXZLVURMM0ppUFJBNFlmK01sRXk2Zk8vWHJPTXc5UnJCYmNMeVlwYVVtNHVkNTlPS3pMeCtwbXUKYUhacXNRS0NBUUJhdkdxSmFhUldPSEtsdTg1YmFObXBtWVpBc0FKanJVSXBSdHFyK0VBUmdQb1hpSmxOTUVtVwp1N3BETXJYM25WaW1WbXN5VVU2NGdMbWZocjRFNHdxWXd1STJ3eUtORUxqRkd5ZFBteFVWQ0dIVzhRTHBBSStoClBuYnljZG0wajhQQlFIYXk4bnNvQVlLNngyMlJpQ0xkWUlSNWdCdjgyeEFNZXVmL1I5QnhUWWl6NE15dE1MaUwKZlRyS3BVbnNnM2pDYWpkaG9nWFpLUDFKQWg4aXVtR3BaRXdnVlhJU3ZwOWtTVjVneFFIOXlsbE4zalVWRW9hRgpHU0RuSTZnbDhrTU1zNnpnVUlJQUZlODBpN0ZoYWQyVHZubzBxZWxoSG1CSDR6T3k5akR5a2NxODJDRU1NVWVCCmlKa2lRNVM5MUNTWTNYTU5IZzhSemorWmNjVy92aVgzQW9JQkFRRE1CRDFadTJaRVIrcXZLcVN6NGpxWVdESmUKNGxGMzhuaWNkV3JyR2g1WXVpN25IYndsWWhWMURNMmlhZkN0UUt0WWZ3aTU4UjFZUzBSTlRyOTlmVUxVV01ITgpPbTZ0eGJuZVBTbytlSk9JWWJzbGZvcXU4YkJPYmNUZjhTemw1b3lzNEJTZDNoYUQ2VDJnWE1aeWNWd0xkVE1mCmQ2bVBtRUlLSElzTG93THJrYS9yR0RRWXhtaGMxT1hKc2dEeVQ5ZFFRakVDcnR6ek1rNHZtR2lwdm5HSVRFTEQKb1NqaStIQ3FTQW8zcjJuWlpEc29wakt6OGl6b2p3RTdaWjY1THdqcDMrSHg4UnhDVThxL29qZTFQV2FDSkVLNAptb2llTlRvZGZQOGFUSGhpcFhNd1lCMUJhUVNqUHVFNUo2dG10OC9BeXZWVWd5czBJOUN0bTM3UVBKY1gKLS0tLS1FTkQgUlNBIFBSSVZBVEUgS0VZLS0tLS0K",
  TOKEN="YES",
  REPORT_READY="YES"]
EOT

        it "finished appliance scripts with success" do
            cmd = @info[:vm].ssh("cat /etc/one-appliance/status")
            expect(cmd.success?).to be(true)
            expect(cmd.stdout.strip).to eq('bootstrap_success')
        end

        it "HTTPs service is working" do
            vm_ip = @info[:vm].xml['TEMPLATE/NIC[1]/IP']

            # Checking permanent redirect to HTTPS
            res = Net::HTTP.get_response(vm_ip, '/')
            expect(res.code).to eq('308')
            expect(res['location']).to include(":443")

            # Check HTTPs (self-signed) is working
            url = URI.parse(res['location'])
            http = Net::HTTP.new(url.host, url.port)
            http.use_ssl = true
            http.verify_mode = OpenSSL::SSL::VERIFY_NONE
            res = http.get(url.request_uri)
            expect(res.code).to eq('200')
            # Checking specific part of the body
            expect(res.body).to include("<title>Harbor</title>")  

        end

        it "HTTPs service is using the provided SSL certificate" do
            vm_ip = @info[:vm].xml['TEMPLATE/NIC[1]/IP']

            # Checking permanent redirect to HTTPS
            res = Net::HTTP.get_response(vm_ip, '/')
            expect(res.code).to eq('308')
            expect(res['location']).to include(":443")

            # Check HTTPs (self-signed) is working
            url = URI.parse(res['location'])
            http = Net::HTTP.new(url.host, url.port)
            http.use_ssl = true
            http.verify_mode = OpenSSL::SSL::VERIFY_NONE
            res = http.get(url.request_uri)
            expect(res.code).to eq('200')

            # Checking that the web server is using the provided SSL certificate
            cmd = @info[:vm].ssh("echo | openssl s_client -showcerts -connect #{vm_ip}:443 2>/dev/null | openssl x509 -text | sed -n '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/p' | base64 --wrap=0")
            expect(cmd.success?).to be(true)
            expect(cmd.stdout).to eq('LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUZXVENDQTBHZ0F3SUJBZ0lKQVBHb2NsU0p5cVR4TUEwR0NTcUdTSWIzRFFFQkN3VUFNRUl4Q3pBSkJnTlYKQkFZVEFsaFlNUlV3RXdZRFZRUUhEQXhFWldaaGRXeDBJRU5wZEhreEhEQWFCZ05WQkFvTUUwUmxabUYxYkhRZwpRMjl0Y0dGdWVTQk1kR1F3SUJjTk1UZ3hNVEl5TVRZd056RTFXaGdQTWpJNU1qQTVNRFl4TmpBM01UVmFNRUl4CkN6QUpCZ05WQkFZVEFsaFlNUlV3RXdZRFZRUUhEQXhFWldaaGRXeDBJRU5wZEhreEhEQWFCZ05WQkFvTUUwUmwKWm1GMWJIUWdRMjl0Y0dGdWVTQk1kR1F3Z2dJaU1BMEdDU3FHU0liM0RRRUJBUVVBQTRJQ0R3QXdnZ0lLQW9JQwpBUURFSXFmNXJ6NFErMFAycjc4V2FpNU50eGtsK2RkbTBsWTFhYzVsTUtVQklCZHRTT0puVXM3MWhJS0tqbzRBCmRZMTF1TTV0Vkd3OWFWMk5FSU1pZ0haZ1VKcENXYVlzdThJOHhHdlZZUHpiRU9YdGh3TWJEMDFhamVrTjJaL3AKc0xPYWpmR3JDWkoxUzAzSUhUK3dRQ09Fb01NYVhMSDFHSHFGRkRmdUxrMTh1a0d6TEZiOVllMFZUV2FBOEN6WApkOUxONnBGdUdHYmxkbU1ORHEvMUVDZHhQQXBoMjJnNDlZbnFWR2xYYVBhbGgwRGlSdEk2eTd2ckFDb2ZGbTFnCnFZbDM3UkJvSTIwcEN1aVNkQUp2UFhYYnQvM0lVUTVEOS9jNkl0ditLbTdGZjM4QlBoZjNXYkc5N3V1NTcycW8KRGRadWhrQ01qVHYxWVRFcnU5NnpyalZrcjJxQWxIM3ZmS2JpeXN5MDJEMFRmQ2RKMVVoS01LTzJYMHpRWG0wYwpFTjl0VjUwdmVNOTdGN2ZiM0Ntc1RKeEFIcnFOSGUzelFHczZnTjlBQVBkOXBJY0tyUS93d0dZNmV0Ykc4OHV0Cm5OdXhDaEZTQVFMTFlYWURmanAvOUVjMGpiK1NDcE9ReDBpL3RrVkRJdERqNkNOZ1JFWE1lUU5aT0lDektVWEYKT2ppRFdITUtUK1BBMFVIYlpFb3BGODdPbERiNlpUaXdrNUFiNW01LzVZOWhXMWIyRlpjd2xNREFPSXQvZ0hLcQpvWEZnc3hTK3BSWFp4SlFFRlZMYVdiU3lPRTFWZXJMWXBzanFYVjh5aEFUdGRpZUs1eFBEUnZwRHVvaGFqeHloCnFuRmgwanpwcEQ2V1dicC9GSzZqZEdkRWJWR2xudDZ5SHhnQnAxbExXek5vMndJREFRQUJvMUF3VGpBZEJnTlYKSFE0RUZnUVVVSzhNdS9ESldQSGVmbFE5Ry9ub1J1VSs3YTB3SHdZRFZSMGpCQmd3Rm9BVVVLOE11L0RKV1BIZQpmbFE5Ry9ub1J1VSs3YTB3REFZRFZSMFRCQVV3QXdFQi96QU5CZ2txaGtpRzl3MEJBUXNGQUFPQ0FnRUFFdnFiCmNGcVJUNFlXNmNLSTc3aExXSk9kcEdWZmlLSUNlVzVVWVhIaWMxV2xHalZjOGk5ZkcwRGpSMy90QW1qbHcxU2MKUEFIQWo1cTJCMitjTDZKU21QYXFrZkRpQVpLeENWaEpDY1hvZHk3TWtTaVhMdUxmdWpLRVBrZjdXL0xKUjdLSQpuREs1ZldqM01wRnYweXRGRjZQb1pWZzdjMzZsL0dBUHJraG1LTW5pME15d2RndDdlTFdPMVhNVW83RWdqcXRpCjhaRTQ2Q3YwY1hzNFVhUmNtL1VLaFBkUnRrSTFrOUg2WW45US9oS0w4Y20yS1BsSklpOVFnQUtxWHRWMlcvcXIKQ0NmN0VqeXdNM0xSSGpMVXlFSE1NQmx1N2RudDg4VUlnNWRmS0dibThoMlozeWRIY0FuelFiOUszZ1NBZjJWMwpSbk53Q0JKSkplMzRKNXlBN21ibENKMUlaNHZEcGxsVkkyVWJJand1K1hpODhaSFkzaFNXOW9LR0huSEdGWHErClRQekUzY0szNW9zVHpTTVpJUVhkeXE3RjhCOG1oM2FNTTNuZWtycEdWZG04cUluQUYyWGRDTjJNekRZNHlQbUEKemNqZDFHWFRPWUtnQnZzYVNvbHpwSm4xQ2x0R01NY1FmSnFtMm1qeXpiVzdsWUZJbnZqNy9rbGRlZjA2UlRXTQpvclh0Z2F6U1dab09GVFBLVjNsSTVoUUNhUEpMbnB4RWJ6ZzNUVmIvY2tNQVM0dXFSVHcyOTlXMFAxYTU3UWthCnNnbjFqamhwNXJUSHlzcWJvd29HaU1vZzJoZHJOSnM1TzFEMzdsZU9hcVZsL0VTVi9VOEJhUnJZTzRZNzFKNFUKK2FTY2FQY0hEWjJnbm1kOU4rZFBTQWVFS1JYWlFoMlQwdFpWeDI0PQotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCg==')
        end

        it "all containers are Healthy" do
            # Bash oneliner to check if all running containers are healthy. 
            cmd = @info[:vm].ssh('all_healthy=1; container_ids=$(docker ps --format "{{.ID}}"); for container_id in $container_ids; do health=$(docker inspect --format "{{.State.Health.Status}}" "$container_id"); if [ "$health" != "healthy" ]; then return 1; fi; done; if [ $all_healthy -eq 1 ]; then return 0; fi')
            expect(cmd.success?).to be(true)
        end

        it "has appliance YAML metadata" do
            cmd = @info[:vm].ssh("cat /etc/one-appliance/metadata")
            expect(cmd.success?).to be(true)
            expect(cmd.stdout.strip).not_to be_empty

            begin
                yaml = YAML.load(cmd.stdout)
            rescue
            end

            expect(yaml.is_a?(Hash)).to be_truthy

            ['name', 'version', 'build', 'description'].each do |key|
                expect(yaml).to have_key(key)

                #TODO: render description with MarkDown
                case key
                when 'build'
                    expect(yaml[key]).to be > 1714994808  # Mon May 06 2024 11:26:48 GMT+0000
                else
                    expect(yaml[key]).not_to be_empty
                end
            end
        end

        it "reports READY=YES via OneGate" do
            vm_ready= @info[:vm].xml['USER_TEMPLATE/READY']
            expect(vm_ready).to eq("YES")
        end

        it "can't remotely connect to PostgreSQL DB" do
            # DB should be exposed in harbor-db docker container => docker internal IP, port 5432
            cmd = SafeExec.run("nc -w2 #{@info[:vm].ip} 5432 </dev/null 2>/dev/null")
            expect(cmd.success?).to be(false)
            expect(cmd.stdout).to be_empty
        end
    end
end
