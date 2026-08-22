Pod::Spec.new do |s|
  s.name             = 'dxtr_card_scan'
  s.version          = '0.1.0'
  s.summary          = 'Rust-backed card scan preprocessing for Flutter.'
  s.description      = <<-DESC
Deterministic Rust preprocessing boundary used by the dxtr_card_scan Flutter package.
                       DESC
  s.homepage         = 'https://github.com/dexter-cnx/dxtr_card_scan'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Dexter CNXcoder' => 'dev@cnxdev.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'
  s.platform = :osx, '10.14'

  s.script_phase = {
    :name => 'Build dxtr_card_scan Rust processor',
    :execution_position => :before_compile,
    :script => 'bash "${PODS_TARGET_SRCROOT}/../tool/build_rust_darwin.sh" "${PODS_TARGET_SRCROOT}/../rust/Cargo.toml" "${PODS_TARGET_SRCROOT}/build/${PLATFORM_NAME}/libdxtr_card_scan_processor.a" "${PODS_TARGET_SRCROOT}/build/rust-target"'
  }

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES'
  }
  s.user_target_xcconfig = {
    'OTHER_LDFLAGS' => '$(inherited) -force_load "$(PODS_ROOT)/../.symlinks/plugins/dxtr_card_scan/macos/build/$(PLATFORM_NAME)/libdxtr_card_scan_processor.a"'
  }
end
