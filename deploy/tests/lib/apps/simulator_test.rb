require_relative "../../test_helper"

class AppsSimulatorTest < Minitest::Test
  def test_builds_and_launches_simulator
    commands = []
    Cmd.stubs(:local).with do |command|
      commands << command
      true
    end.returns(<<~DEVICES)
      iPhone 17 Pro (00000000-0000-0000-0000-000000000000) (Booted)
      iPhone 16 Pro (11111111-1111-1111-1111-111111111111) (Booted)
      iPad Pro (22222222-2222-2222-2222-222222222222) (Booted)
    DEVICES

    Apps::Simulator.call("iphone")

    assert commands.any? { |command| command.include?("xcodebuild") }
    assert_includes commands, "xcrun simctl shutdown 00000000-0000-0000-0000-000000000000"
    assert_includes commands, "xcrun simctl shutdown 11111111-1111-1111-1111-111111111111"
    refute_includes commands, "xcrun simctl shutdown 22222222-2222-2222-2222-222222222222"
    assert commands.any? { |command| command.include?("simctl install") }
    assert commands.any? { |command| command.include?("simctl launch") }
  end

  def test_accepts_iphone_and_ipad_aliases
    Cmd.stubs(:local).returns(<<~DEVICES)
      iPhone 17 Pro (00000000-0000-0000-0000-000000000000) (Shutdown)
      iPad Pro (11111111-1111-1111-1111-111111111111) (Shutdown)
    DEVICES

    [ "iphone", "phone", "ipad", "tablet" ].each { |name| Apps::Simulator.call(name) }
  end

  def test_rejects_unknown_simulator
    error = assert_raises(RuntimeError) { Apps::Simulator.call("watch") }

    assert_includes error.message, "Unknown simulator"
  end

  def test_builds_and_launches_macos_app
    config_path = File.join(Apps.root, "config.json")
    config = JSON.parse(File.read(config_path))
    config.fetch("targets").fetch("apple")["macos"] = {
      archiveDestination: "generic/platform=macOS",
      bundleIdentifier: "org.example.app",
      platform: "MAC_OS",
      project: File.join(Apps.root, "apple", "App.xcodeproj"),
      scheme: "App-macOS",
      simulatorDestination: "platform=macOS",
      simulatorProduct: "Debug/App-macOS.app",
      simulators: { macos: "Mac" },
    }
    File.write(config_path, JSON.generate(config))
    Apps.reset
    Apps.root = File.join(@deploy_test_dir, "apps")
    Apps.tmp_root = File.join(@deploy_test_dir, "artifacts")
    app_path = File.join(Apps.tmp_root, "simulate", "macos", "Build", "Products", "Debug", "App-macOS.app")
    FileUtils.mkdir_p(app_path)
    File.write(File.join(app_path, "stale"), "stale")
    commands = []
    removed_before_build = false
    Cmd.stubs(:local).with do |command|
      commands << command
      removed_before_build = !File.exist?(app_path) if command.include?("xcodebuild")
      true
    end.returns("")

    [ "mac", "macos", "osx" ].each { |name| Apps::Simulator.call(name) }

    assert commands.any? { |command| command.include?("platform\\=macOS") }
    assert removed_before_build
    assert commands.any? { |command| command == "pkill -x App-macOS" }
    assert commands.any? { |command| command.include?("open") && command.include?("App-macOS.app") }
    refute commands.any? { |command| command.include?("simctl") }
  end

  def test_accepts_tv_aliases
    config_path = File.join(Apps.root, "config.json")
    config = JSON.parse(File.read(config_path))
    config.fetch("targets").fetch("apple")["tvos"] = {
      archiveDestination: "generic/platform=tvOS",
      bundleIdentifier: "org.example.tv-app",
      platform: "TV_OS",
      project: File.join(Apps.root, "apple", "App.xcodeproj"),
      scheme: "App-tvOS",
      simulatorDestination: "generic/platform=tvOS Simulator",
      simulatorProduct: "Debug-appletvsimulator/App-tvOS.app",
      simulators: { tv: "Apple TV" },
    }
    File.write(config_path, JSON.generate(config))
    Apps.reset
    Apps.root = File.join(@deploy_test_dir, "apps")
    Apps.tmp_root = File.join(@deploy_test_dir, "artifacts")
    Cmd.stubs(:local).returns("Apple TV 4K (00000000-0000-0000-0000-000000000000) (Shutdown)")

    [ "tv", "tvos" ].each { |name| Apps::Simulator.call(name) }
  end
end
