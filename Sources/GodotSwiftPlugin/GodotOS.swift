// MIT License
//
// Copyright (c) 2026-present Poing Studios
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Foundation

#if canImport(UIKit)
import UIKit
#endif

public enum GodotOS {
    public typealias FocusCallback = @convention(c) () -> Void

    private static var onFocusOutCallback: FocusCallback?
    private static var onFocusInCallback: FocusCallback?

    public static var customFocusOutHandler: (() -> Void)?
    public static var customFocusInHandler: (() -> Void)?

    #if canImport(UIKit)
    public static var rootViewController: UIViewController? {
        if #available(iOS 13.0, tvOS 13.0, *) {
            for scene in UIApplication.shared.connectedScenes {
                guard let windowScene = scene as? UIWindowScene else { continue }
                if let window = windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first {
                    if let root = window.rootViewController {
                        return root
                    }
                }
            }
        }
        return UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.rootViewController
            ?? UIApplication.shared.keyWindow?.rootViewController
            ?? UIApplication.shared.delegate?.window??.rootViewController
    }
    #endif

    public static func setFocusCallbacks(
        focusOut: FocusCallback?,
        focusIn: FocusCallback?
    ) {
        onFocusOutCallback = focusOut
        onFocusInCallback = focusIn
    }

    public static func onFocusOut() {
        if let custom = customFocusOutHandler {
            custom()
        } else {
            onFocusOutCallback?()
        }
    }

    public static func onFocusIn() {
        if let custom = customFocusInHandler {
            custom()
        } else {
            onFocusInCallback?()
        }
    }
}

@_cdecl("godot_swift_set_focus_callbacks")
public func godot_swift_set_focus_callbacks(
    _ onFocusOut: (@convention(c) () -> Void)?,
    _ onFocusIn: (@convention(c) () -> Void)?
) {
    GodotOS.setFocusCallbacks(focusOut: onFocusOut, focusIn: onFocusIn)
}
