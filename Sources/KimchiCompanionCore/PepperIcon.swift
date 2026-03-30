import SwiftUI
import AppKit

/// Provides the Kimchi pepper icon as a macOS template image for the menu bar.
///
/// The pepper silhouette is embedded as base64 PNG data (black on transparent).
/// It's set as a template image so macOS automatically renders it in the correct
/// color for the current menu bar appearance (light/dark).
public enum PepperIcon {

    // MARK: - Embedded Image Data

    /// 36×36 pepper silhouette PNG, base64-encoded.
    private static let pepperBase64 = "iVBORw0KGgoAAAANSUhEUgAAACQAAAAkCAYAAADhAJiYAAAAAXNSR0IArs4c6QAAADhlWElmTU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAAAqACAAQAAAABAAAAJKADAAQAAAABAAAAJAAAAAAJxsHGAAAEgklEQVRYCc3VSayeYxjG8RprroOiSpVEDSFIDFESiYVEIhEWGgsRG1sbO5YSKwmRWBkiqTSRLiQEK4uaEpSY2hK01ZZKqzXP0/+XnPeL71BOTxend/LP+37vM9zXcz3383xz5uxjsd8UPYf1++L4I7bGr5Pv+/c8IDyN0e6J30K/Q+LQODB8+y6Eb+Y9KLbE+7HLMPivIemSuDs2xqow0Y9BxEQcPPluLIHESC7pgknMsyF+DuNPijPDIu+IJ+Mfw8C/hgneiPWxLI6MzfFLWPW3wRVBCKGDa9/3vjPMMbTpT+yXk8/Tel4ZFrsu/hZTBQ0d1vZisuuDK1bGIUGYVXuK34Ngc3HtmyDUN9gyi/gp9OUiUa/FphiLXQnSaXVsixvDdhhMiBUTNySSVCJtvnPIb6GPdt/BRY7Oj6XxfOyIUfybIJ3eik/ittD38zAxx44KQn8IYZswbOEgcm7fvHOJq0M9qlVb+ESM4r8E6fheSHxtSM4hTyvz3emSCMQMEAHt8vg+bLVyUJ8nxX0xCp2mE/fXaU2cF5w5ItTKllA3Vi8pUYMbnOSGQpdHO0GE6LMhvo6xmI5DBth7q7ouJFJbJuWSZAT6DmFeIvVRzN4HN20h19QaQctjFNMVZICtOzsuDyv/Khxnk54QQ1GbcxDHMQJsMQgjBhayPVbGKKa7ZcOAu3pRQ4vimDg+JLd13JBcUsXtdInFcXIQvzU4Bn24Pha7K0jil4OQ44IzRGwITg0uESeh+lK4p8e84BgR3OWyfmOxu4IMfjQk8hfCJUVqxZsmn9oI45T5bZW+aujw4ChRxGkbC4N3N95pwKexMAg5NWyHwvfkHCFQuO4yThJIFEEuzFOCq2MxE4eI+Dgcf6fNlpnc4rQRYV6uaHPsuScG107snUhbPxYzEWRVa8J2fRGbgzg1Yj51YcsWxeIgwtYQTCx3tB0dC2IsZrJlTs/bQYRVfhDEqA/hFB4bZwSHuLYxFDLBxri3fJ+IsZiJQyZwJ30WF4TJJTaXk8NBtzgB3Lgqzg0CTg93mXaL4hwHRzEThwxeG2+GS9LWifnhnnGCuCU5t7xfGmcFV+V8MRS3Ns9RWNVMQi08F+6aC0MtOWWScUixqpHV8XisD9vqqL8QH8WOeDXGYqYOmeSxuCYuC9vzbvhLsEXcIdbfyIbwnVv6vR5D/fk+FmP7N9YyvR9L6sapiSDACSNiEMO5V4IQhb4z1NVpof4ckAUxCoP3JCS0qKvDpfdsrIxVsSV844Y8asUB8Dwn3F0r4qkYxZ4KMpE7Sb1cFGpHUTtRm4MjRLgInSxtyuSSWBe3hq0cxZ7U0DCJIr4ztsYNcXMIiRSuLcK2UD9XTP5e3nN7jMXeEGRCK78nHonzQ324jQlxspYGV9TT3BDqSs39byHx4M4tvaudh+LBIGZFaJ+VWFjWt+LDUDcvhTq7KWYtbi8zES7KB8LV4CTOWhxU5nvDaVsZz8TGcG3MWswrMzFEPR1O2qzHRAo45Urg0j4RLuRl8XDM6pZNdWNv3YNT5917v/8EreAynFDtb8QAAAAASUVORK5CYII="

    /// Returns the pepper icon as a template NSImage, or nil if decoding fails.
    public static func image() -> NSImage? {
        guard let data = Data(base64Encoded: pepperBase64) else { return nil }
        guard let image = NSImage(data: data) else { return nil }
        image.isTemplate = true  // macOS adapts color for light/dark menu bar
        return image
    }

    /// Returns the pepper icon as a SwiftUI Image, or a fallback SF Symbol.
    public static var swiftUIImage: Image {
        if let nsImage = image() {
            return Image(nsImage: nsImage)
        }
        return Image(systemName: "flame.fill")
    }
}
