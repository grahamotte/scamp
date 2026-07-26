#!/usr/bin/env ruby
# frozen_string_literal: true

require "base64"
require "json"
require "net/http"
require "openssl"
require "time"
require "uri"

class AppStoreConnect
  BASE = "https://api.appstoreconnect.apple.com"
  REVIEWING = %w[WAITING_FOR_REVIEW IN_REVIEW].freeze
  CANCELING = %w[CANCELING COMPLETING].freeze
  LOCALIZATION_FIELDS = %w[description keywords marketingUrl promotionalText supportUrl whatsNew].freeze
  REVIEW_FIELDS = %w[contactEmail contactFirstName contactLastName contactPhone
                     demoAccountName demoAccountPassword demoAccountRequired notes].freeze

  def initialize
    @key_id = ENV.fetch("APPLE_KEY_ID")
    @issuer_id = ENV.fetch("APPLE_ISSUER_ID")
    @key = OpenSSL::PKey.read(Base64.decode64(ENV.fetch("APPLE_KEY_P8_BASE64")))
    @interval = Integer(ENV.fetch("ASC_POLL_INTERVAL", "10"))
    @timeout = Integer(ENV.fetch("ASC_POLL_TIMEOUT", "1200"))
  end

  def validate(bundle_id:, platform:, version:)
    app = app_for(bundle_id)
    versions = versions_for(app.fetch("id"), platform)
    target = versions.find { |item| item.dig("attributes", "versionString") == version }
    source = metadata_source(versions, target)
    raise "No existing #{platform} version metadata is available to copy" unless source

    raise "No existing #{platform} localizations are available to copy" if localizations(source.fetch("id")).empty?
    raise "No existing #{platform} App Review details are available to copy" unless review_detail(source.fetch("id"))

    get("/v1/appStoreVersions/#{source.fetch("id")}/relationships/build")
    submissions(app.fetch("id"), platform).each do |submission|
      submission_items(submission.fetch("id")) if
        (REVIEWING + CANCELING + ["READY_FOR_REVIEW"]).include?(submission.dig("attributes", "state"))
    end
    puts "Validated read-only App Store Connect access for #{platform} #{version}."
  end

  def submit(bundle_id:, platform:, version:, build:)
    app = app_for(bundle_id)
    app_id = app.fetch("id")
    versions = versions_for(app_id, platform)
    target = versions.find { |item| item.dig("attributes", "versionString") == version }
    uploaded_build = find_build(app_id, platform, version, build)
    return if target && uploaded_build && already_submitted?(app_id, platform, target, uploaded_build)

    cancel_active_submissions(app_id, platform)
    versions = versions_for(app_id, platform)
    target = versions.find { |item| item.dig("attributes", "versionString") == version }
    reusable = versions.select { |item| item.dig("attributes", "appStoreState") == "DEVELOPER_REJECTED" }
                       .max_by { |item| item.dig("attributes", "createdDate").to_s }
    source = metadata_source(versions, target || reusable)
    raise "No existing #{platform} version metadata is available to copy" unless source

    target ||= reusable ? update_version(reusable, version) :
                          create_version(app_id, platform, version, source.fetch("attributes"))
    copy_localizations(source.fetch("id"), target.fetch("id"))
    copy_review_details(source.fetch("id"), target.fetch("id"))

    uploaded_build ||= wait_for_build(app_id, platform, version, build)
    attach_build(target.fetch("id"), uploaded_build)
    submit_version(app_id, platform, target.fetch("id"))
    puts "Submitted #{platform} #{version} (build #{build}) to App Review."
  end

  private

  def app_for(bundle_id)
    get("/v1/apps", query: { "filter[bundleId]" => bundle_id, "limit" => 2 }).fetch("data").sole
  end

  def versions_for(app_id, platform)
    get("/v1/apps/#{app_id}/appStoreVersions",
        query: { "filter[platform]" => platform, "limit" => 200 }).fetch("data")
  end

  def submissions(app_id, platform)
    get("/v1/apps/#{app_id}/reviewSubmissions",
        query: { "filter[platform]" => platform, "limit" => 200 }).fetch("data")
  end

  def metadata_source(versions, target)
    prior = versions.reject { |item| item["id"] == target&.fetch("id") }
                    .max_by { |item| item.dig("attributes", "createdDate").to_s }
    if target&.dig("attributes", "appStoreState") == "PREPARE_FOR_SUBMISSION" && prior
      return prior if localizations(target.fetch("id")).length < localizations(prior.fetch("id")).length
    end

    target || prior
  end

  def cancel_active_submissions(app_id, platform)
    active = submissions(app_id, platform).select do |item|
      (REVIEWING + CANCELING).include?(item.dig("attributes", "state"))
    end

    active.each do |item|
      state = item.dig("attributes", "state")
      next unless REVIEWING.include?(state)

      puts "Canceling #{platform} review submission #{item.fetch("id")} (#{state})..."
      patch("/v1/reviewSubmissions/#{item.fetch("id")}",
            data: { type: "reviewSubmissions", id: item.fetch("id"), attributes: { canceled: true } })
    end
    active.each { |item| wait_until_canceled(item.fetch("id"), platform) }
  end

  def wait_until_canceled(id, platform)
    wait("cancellation of #{platform} submission #{id}") do
      state = get("/v1/reviewSubmissions/#{id}").dig("data", "attributes", "state")
      puts "Waiting for #{platform} review cancellation (#{state})..." if (REVIEWING + CANCELING).include?(state)
      !(REVIEWING + CANCELING).include?(state)
    end
  end

  def create_version(app_id, platform, version, source)
    attributes = {
      platform: platform,
      versionString: version,
      copyright: source["copyright"],
      releaseType: source["releaseType"] || "MANUAL",
      usesIdfa: source["usesIdfa"]
    }.compact
    attributes[:earliestReleaseDate] = source["earliestReleaseDate"] if attributes[:releaseType] == "SCHEDULED"

    puts "Creating #{platform} App Store version #{version}..."
    post("/v1/appStoreVersions",
         data: {
           type: "appStoreVersions",
           attributes: attributes,
           relationships: { app: { data: { type: "apps", id: app_id } } }
         }).fetch("data")
  end

  def update_version(version, version_string)
    puts "Updating #{version.dig("attributes", "platform")} App Store version to #{version_string}..."
    patch("/v1/appStoreVersions/#{version.fetch("id")}",
          data: {
            type: "appStoreVersions",
            id: version.fetch("id"),
            attributes: { versionString: version_string }
          }).fetch("data")
  end

  def localizations(version_id)
    get("/v1/appStoreVersions/#{version_id}/appStoreVersionLocalizations",
        query: { "limit" => 50 }).fetch("data")
  end

  def copy_localizations(source_id, target_id)
    source = localizations(source_id)
    target = localizations(target_id)
    target_by_locale = target.to_h do |item|
      [item.dig("attributes", "locale"), item]
    end

    (source + target).uniq { |item| item.dig("attributes", "locale") }.each do |item|
      attributes = item.fetch("attributes").slice(*LOCALIZATION_FIELDS).compact
      locale = item.dig("attributes", "locale")
      attributes["whatsNew"] = "Bug fixes."

      if (existing = target_by_locale[locale])
        patch("/v1/appStoreVersionLocalizations/#{existing.fetch("id")}",
              data: { type: "appStoreVersionLocalizations", id: existing.fetch("id"), attributes: attributes })
      else
        post("/v1/appStoreVersionLocalizations",
             data: {
               type: "appStoreVersionLocalizations",
               attributes: attributes.merge("locale" => locale),
               relationships: {
                 appStoreVersion: { data: { type: "appStoreVersions", id: target_id } }
               }
             })
      end
    end
  end

  def review_detail(version_id)
    get("/v1/appStoreVersions/#{version_id}/appStoreReviewDetail", allow: [404])
  end

  def copy_review_details(source_id, target_id)
    source = review_detail(source_id)
    raise "No existing App Review details are available to copy" unless source

    attributes = source.fetch("data").fetch("attributes").slice(*REVIEW_FIELDS).compact
    target = review_detail(target_id)
    if target
      id = target.dig("data", "id")
      patch("/v1/appStoreReviewDetails/#{id}",
            data: { type: "appStoreReviewDetails", id: id, attributes: attributes })
    else
      post("/v1/appStoreReviewDetails",
           data: {
             type: "appStoreReviewDetails",
             attributes: attributes,
             relationships: {
               appStoreVersion: { data: { type: "appStoreVersions", id: target_id } }
             }
           })
    end
  end

  def build_response(app_id, platform, version, build)
    get("/v1/preReleaseVersions",
        query: {
          "filter[app]" => app_id,
          "filter[platform]" => platform,
          "filter[version]" => version,
          "filter[builds.version]" => build,
          "include" => "builds",
          "limit" => 1,
          "limit[builds]" => 50
        })
  end

  def find_build(app_id, platform, version, build)
    builds = build_response(app_id, platform, version, build).fetch("included", [])
    builds.select { |item| item["type"] == "builds" &&
      item.dig("attributes", "processingState") == "VALID" }
          .max_by { |item| item.dig("attributes", "uploadedDate").to_s }
  end

  def wait_for_build(app_id, platform, version, build)
    wait("#{platform} build #{version} (#{build}) to process") do
      find_build(app_id, platform, version, build) ||
        (puts("Waiting for #{platform} build #{version} (#{build}) to process..."); false)
    end
  end

  def attach_build(version_id, build)
    attached = get("/v1/appStoreVersions/#{version_id}/relationships/build").dig("data", "id")
    return if attached == build.fetch("id")

    patch("/v1/appStoreVersions/#{version_id}/relationships/build",
          data: { type: "builds", id: build.fetch("id") })
  end

  def already_submitted?(app_id, platform, version, build)
    attached = get("/v1/appStoreVersions/#{version.fetch("id")}/relationships/build").dig("data", "id")
    return false unless attached == build.fetch("id") && release_notes_complete?(version.fetch("id"))

    submissions(app_id, platform).any? do |submission|
      next unless REVIEWING.include?(submission.dig("attributes", "state"))

      submission_items(submission.fetch("id")).any? do |item|
        item.dig("relationships", "appStoreVersion", "data", "id") == version.fetch("id")
      end
    end.tap do |done|
      puts "#{platform} #{version.dig("attributes", "versionString")} is already under review." if done
    end
  end

  def release_notes_complete?(version_id)
    notes = localizations(version_id)
    !notes.empty? && notes.all? { |item| item.dig("attributes", "whatsNew") == "Bug fixes." }
  end

  def submission_items(submission_id)
    get("/v1/reviewSubmissions/#{submission_id}/items",
        query: { "include" => "appStoreVersion", "limit" => 50 }).fetch("data")
  end

  def submit_version(app_id, platform, version_id)
    drafts = submissions(app_id, platform).select do |item|
      item.dig("attributes", "state") == "READY_FOR_REVIEW"
    end
    submission = drafts.first || post("/v1/reviewSubmissions",
                                      data: {
                                        type: "reviewSubmissions",
                                        relationships: { app: { data: { type: "apps", id: app_id } } }
                                      }).fetch("data")

    items = submission_items(submission.fetch("id"))
    current = items.find { |item| item.dig("relationships", "appStoreVersion", "data", "id") == version_id }
    items.each do |item|
      related = item.dig("relationships", "appStoreVersion", "data")
      delete("/v1/reviewSubmissionItems/#{item.fetch("id")}") if related && related["id"] != version_id
    end

    unless current
      post("/v1/reviewSubmissionItems",
           data: {
             type: "reviewSubmissionItems",
             relationships: {
               reviewSubmission: {
                 data: { type: "reviewSubmissions", id: submission.fetch("id") }
               },
               appStoreVersion: { data: { type: "appStoreVersions", id: version_id } }
             }
           })
    end

    patch("/v1/reviewSubmissions/#{submission.fetch("id")}",
          data: {
            type: "reviewSubmissions",
            id: submission.fetch("id"),
            attributes: { submitted: true }
          })
  end

  def wait(description)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + @timeout
    loop do
      value = yield
      return value if value
      raise "Timed out waiting for #{description}" if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

      sleep @interval
    end
  end

  def get(path, query: nil, allow: [])
    request(Net::HTTP::Get, path, query: query, expected: [200], allow: allow)
  end

  def post(path, data:)
    request(Net::HTTP::Post, path, body: { data: data }, expected: [201])
  end

  def patch(path, data:)
    request(Net::HTTP::Patch, path, body: { data: data }, expected: [200, 204])
  end

  def delete(path)
    request(Net::HTTP::Delete, path, expected: [204])
  end

  def request(request_class, path, query: nil, body: nil, expected:, allow: [])
    uri = URI("#{BASE}#{path}")
    uri.query = URI.encode_www_form(query) if query
    request = request_class.new(uri)
    request["Authorization"] = "Bearer #{token}"
    request["Content-Type"] = "application/json"
    request.body = JSON.generate(body) if body
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }
    return nil if allow.include?(response.code.to_i)

    unless expected.include?(response.code.to_i)
      details = JSON.parse(response.body).fetch("errors", []).map { |error| error["detail"] || error["title"] }
      raise "#{request.method} #{path} failed (#{response.code}): #{details.join("; ")}"
    end

    response.body.to_s.empty? ? nil : JSON.parse(response.body)
  end

  def token
    now = Time.now.to_i
    header = encode(alg: "ES256", kid: @key_id, typ: "JWT")
    payload = encode(iss: @issuer_id, iat: now, exp: now + 1_200, aud: "appstoreconnect-v1")
    input = "#{header}.#{payload}"
    signature = OpenSSL::ASN1.decode(@key.sign(OpenSSL::Digest::SHA256.new, input)).value
    raw = signature.map { |integer| integer.value.to_s(2).rjust(32, "\0") }.join
    "#{input}.#{Base64.urlsafe_encode64(raw, padding: false)}"
  end

  def encode(value)
    Base64.urlsafe_encode64(JSON.generate(value), padding: false)
  end
end

class Array
  def sole
    raise "Expected one App Store Connect resource, found #{length}" unless length == 1

    first
  end
end

if __FILE__ == $PROGRAM_NAME
  if ARGV.first == "--validate" && ARGV.length == 4
    AppStoreConnect.new.validate(platform: ARGV[1], bundle_id: ARGV[2], version: ARGV[3])
  elsif ARGV.length == 4
    AppStoreConnect.new.submit(platform: ARGV[0], bundle_id: ARGV[1], version: ARGV[2], build: ARGV[3])
  else
    warn "Usage: #{$PROGRAM_NAME} [--validate] PLATFORM BUNDLE_ID VERSION [BUILD]"
    exit 1
  end
end
