//
//  FontRegistrar.swift
//  SurfaceDrawingEditor
//
//  Created by _d3n_o77 on 26.02.2026.
//

import UIKit
import CoreText

enum FontRegistrar {
    static var isRegistered = false
    
    public static func registerIfNeeded() {
        guard !isRegistered else { return }
        isRegistered = true
        
        let bundle = Bundle.module
        guard let urls = bundle.urls(forResourcesWithExtension: "otf", subdirectory: nil)
            ?? bundle.urls(forResourcesWithExtension: "ttf", subdirectory: nil)
        else { return }
        
        urls.forEach { url in
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
