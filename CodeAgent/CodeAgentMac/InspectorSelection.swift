//
//  InspectorSelection.swift
//  CodeAgent
//
//  Created by xiaoyuan on 2026/6/24.
//

import Foundation

enum InspectorSelection: Hashable {
    case file(String)
    case todo(String)
    case tool(String)
    case plan(String)
}
