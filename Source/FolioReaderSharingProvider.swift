//
//  FolioReaderSharingProvider.swift
//  FolioReaderKit
//
//  Created by Heberti Almeida on 02/09/15.
//  Copyright (c) 2015 Folio Reader. All rights reserved.
//

import UIKit

class FolioReaderSharingProvider: UIActivityItemProvider {

    var subject: String
    var text: String
    var html: String?

    init(subject: String, text: String, html: String?) {
        self.subject = subject
        self.text = text
        self.html = html

        super.init(placeholderItem: "")
    }

    override func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivityType?) -> String {
        return subject
    }

    override func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivityType) -> Any? {
        if let html = html , activityType == UIActivityType.mail {
            return html
        }

        return text
    }
}
