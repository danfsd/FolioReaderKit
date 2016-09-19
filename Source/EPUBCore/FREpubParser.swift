//
//  FREpubParser.swift
//  FolioReaderKit
//
//  Created by Heberti Almeida on 04/05/15.
//  Copyright (c) 2015 Folio Reader. All rights reserved.
//

import UIKit
#if COCOAPODS
import SSZipArchive
#else
import ZipArchive
#endif
import AEXML

class FREpubParser: NSObject, SSZipArchiveDelegate {
    let book = FRBook()
    var bookBasePath: String!
    var resourcesBasePath: String!
    var shouldRemoveEpub = true
    fileprivate var epubPathToRemove: String?
    
    /**
     Parse the Cover Image from an epub file.
     Returns an UIImage.
     */
    func parseCoverImage(_ epubPath: String)-> UIImage? {

        let book = readEpub(epubPath: epubPath, removeEpub: false)
        
        // Read the cover image
        if let coverImage = book.coverImage {
            return UIImage(contentsOfFile: coverImage.fullHref)
        }
        
        return nil
    }
    
    /**
     Unzip, delete and read an epub file.
     Returns a FRBook.
    */
    func readEpub(epubPath withEpubPath: String, removeEpub: Bool = true) -> FRBook {
        epubPathToRemove = withEpubPath
        shouldRemoveEpub = removeEpub
        
        // Unzip   
        let bookName = (withEpubPath as NSString).lastPathComponent
        bookBasePath = (kApplicationDocumentsDirectory as NSString).appendingPathComponent(bookName)
        SSZipArchive.unzipFile(atPath: withEpubPath, toDestination: bookBasePath, delegate: self)
        
        // Skip from backup this folder
        _ = addSkipBackupAttributeToItemAtURL(URL(fileURLWithPath: bookBasePath, isDirectory: true))
        
        kBookId = bookName
        readContainer()
        readOpf()
        return book
    }
    
    
    /**
     Read an unziped epub file.
     Returns a FRBook.
    */
    func readEpub(filePath withFilePath: String) -> FRBook {
        bookBasePath = withFilePath
        kBookId = (withFilePath as NSString).lastPathComponent
        readContainer()
        readOpf()
        return book
    }
    
    /**
     Read and parse container.xml file.
    */
    fileprivate func readContainer() {
        let containerPath = "META-INF/container.xml"
        let containerData = try? Data(contentsOf: URL(fileURLWithPath: (bookBasePath as NSString).appendingPathComponent(containerPath)), options: .alwaysMapped)
        
        do {
            let xmlDoc = try AEXMLDocument(xml: containerData!)
            let opfResource = FRResource()
            opfResource.href = xmlDoc.root["rootfiles"]["rootfile"].attributes["full-path"]
            opfResource.mediaType = FRMediaType.determineMediaType(xmlDoc.root["rootfiles"]["rootfile"].attributes["full-path"]!)
            book.opfResource = opfResource
            resourcesBasePath = (bookBasePath as NSString).appendingPathComponent((book.opfResource.href as NSString).deletingLastPathComponent)
        } catch {
            print("Cannot read container.xml")
        }
    }
    
    /**
     Read and parse .opf file.
    */
    fileprivate func readOpf() {
        let opfPath = (bookBasePath as NSString).appendingPathComponent(book.opfResource.href)
        let opfData = try? Data(contentsOf: URL(fileURLWithPath: opfPath), options: .alwaysMapped)
        
        do {
            let xmlDoc = try AEXMLDocument(xml: opfData!)
            
            // parse and save each "manifest item"
            for item in xmlDoc.root["manifest"]["item"].all! {
                let resource = FRResource()
                resource.id = item.attributes["id"]
                resource.href = item.attributes["href"]
                resource.fullHref = (NSString(string: resourcesBasePath).appendingPathComponent(item.attributes["href"]!).removingPercentEncoding)
                resource.mediaType = FRMediaType.mediaTypeByName(item.attributes["media-type"]!, fileName: resource.href)
                resource.mediaOverlay = item.attributes["media-overlay"]
                
                // if a .smil file is listed in resources, go parse that file now and save it on book model
                if( resource.mediaType != nil && resource.mediaType == FRMediaType.SMIL ){
                    readSmilFile(resource);
                }
                
                book.resources.add(resource)
            }
            
            book.smils.basePath = resourcesBasePath

            // Get the first resource with the NCX mediatype
            if let ncxResource = book.resources.findFirstResource(byMediaType: FRMediaType.NCX) {
                book.ncxResource = ncxResource
            }
            
            // Non-standard books may use wrong mediatype, fallback with extension
            if let ncxResource = book.resources.findFirstResource(byExtension: FRMediaType.NCX.defaultExtension) {
                book.ncxResource = ncxResource
            }
            
            assert(book.ncxResource != nil, "ERROR: Could not find table of contents resource. The book don't have a NCX resource.")
            
            // The book TOC
            book.tableOfContents = findTableOfContents()
            book.flatTableOfContents = createFlatTOC()
            
            // Read metadata
            book.metadata = readMetadata(xmlDoc.root["metadata"].children)
            
            // Read the cover image
            let coverImageID = book.metadata.findMetaByName("cover")
            if (coverImageID != nil && book.resources.containsById(coverImageID!)) {
                book.coverImage = book.resources.getById(coverImageID!)
            }
            
            // Read Spine
            book.spine = readSpine(xmlDoc.root["spine"].children)
        } catch {
            print("Cannot read .opf file.")
        }
    }
    
    /**
     Reads and parses a .smil file
    */
    fileprivate func readSmilFile(_ resource: FRResource){
        let smilData = try? Data(contentsOf: URL(fileURLWithPath: resource.fullHref), options: .alwaysMapped)
        
        var smilFile = FRSmilFile(resource: resource);
        
        do {
            let xmlDoc = try AEXMLDocument(xml: smilData!)
            
            let children = xmlDoc.root["body"].children

            if( children.count > 0 ){
                smilFile.data.append(contentsOf: readSmilFileElements(children) )
            }
            
        } catch {
            print("Cannot read .smil file: "+resource.href)
        }
        
        book.smils.add(smilFile);
    }
    
    fileprivate func readSmilFileElements(_ children:[AEXMLElement]) -> [FRSmilElement] {

        var data = [FRSmilElement]()

        // convert each smil element to a FRSmil object
        for item in children {

            let smil = FRSmilElement(name: item.name, attributes: item.attributes)

            // if this element has children, convert them to objects too
            if( item.children.count > 0 ){
                smil.children.append( contentsOf: readSmilFileElements(item.children) )
            }

            data.append(smil)
        }

        return data
    }

    /**
     Read and parse the Table of Contents.
    */
    fileprivate func findTableOfContents() -> [FRTocReference] {
        let ncxPath = (resourcesBasePath as NSString).appendingPathComponent(book.ncxResource.href)
        let ncxData = try? Data(contentsOf: URL(fileURLWithPath: ncxPath), options: .alwaysMapped)
        var tableOfContent = [FRTocReference]()
        
        do {
            let xmlDoc = try AEXMLDocument(xml: ncxData!)
            for item in xmlDoc.root["navMap"]["navPoint"].all! {
                tableOfContent.append(readTOCReference(item))
            }
        } catch {
            print("Cannot find Table of Contents.")
        }
        return tableOfContent
    }
    
    fileprivate func readTOCReference(_ navpointElement: AEXMLElement) -> FRTocReference {
        var label = ""
        
        if let labelText = navpointElement["navLabel"]["text"].value {
            label = labelText
        }
        
        let reference = navpointElement["content"].attributes["src"]
        let hrefSplit = reference!.characters.split {$0 == "#"}.map { String($0) }
        let fragmentID = hrefSplit.count > 1 ? hrefSplit[1] : ""
        let href = hrefSplit[0]
        
        let resource = book.resources.getByHref(href)
        let toc = FRTocReference(title: label, resource: resource, fragmentID: fragmentID)
        
        if navpointElement["navPoint"].all != nil {
            for navPoint in navpointElement["navPoint"].all! {
                toc.children.append(readTOCReference(navPoint))
            }
        }        
        return toc
    }
    
    // MARK: - Recursive add items to a list
    
    func createFlatTOC() -> [FRTocReference] {
        var tocItems = [FRTocReference]()
        
        for item in book.tableOfContents {
            tocItems.append(item)
            tocItems.append(contentsOf: countTocChild(item))
        }
        return tocItems
    }
    
    func countTocChild(_ item: FRTocReference) -> [FRTocReference] {
        var tocItems = [FRTocReference]()
        
        if item.children.count > 0 {
            for item in item.children {
                tocItems.append(item)
            }
        }
        return tocItems
    }
    
    /**
     Read and parse <metadata>.
    */
    fileprivate func readMetadata(_ tags: [AEXMLElement]) -> FRMetadata {
        let metadata = FRMetadata()
        
        for tag in tags {
            if tag.name == "dc:title" {
                metadata.titles.append(tag.value ?? "")
            }
            
            if tag.name == "dc:identifier" {
                metadata.identifiers.append(Identifier(scheme: tag.attributes["opf:scheme"] ?? "", value: tag.value ?? ""))
            }
            
            if tag.name == "dc:language" {
                let language = tag.value ?? metadata.language
                metadata.language = language != "en" ? language : metadata.language
            }
            
            if tag.name == "dc:creator" {
                metadata.creators.append(Author(name: tag.value ?? "", role: tag.attributes["opf:role"] ?? "", fileAs: tag.attributes["opf:file-as"] ?? ""))
            }
            
            if tag.name == "dc:contributor" {
                metadata.creators.append(Author(name: tag.value ?? "", role: tag.attributes["opf:role"] ?? "", fileAs: tag.attributes["opf:file-as"] ?? ""))
            }
            
            if tag.name == "dc:publisher" {
                metadata.publishers.append(tag.value ?? "")
            }
            
            if tag.name == "dc:description" {
                metadata.descriptions.append(tag.value ?? "")
            }
            
            if tag.name == "dc:subject" {
                metadata.subjects.append(tag.value ?? "")
            }
            
            if tag.name == "dc:rights" {
                metadata.rights.append(tag.value ?? "")
            }
            
            if tag.name == "dc:date" {
                metadata.dates.append(Date(date: tag.value ?? "", event: tag.attributes["opf:event"] ?? ""))
            }
            
            if tag.name == "meta" {
                if tag.attributes["name"] != nil {
                    metadata.metaAttributes.append(Meta(name: tag.attributes["name"]!, content: (tag.attributes["content"] ?? "")))
                }
                
                if tag.attributes["property"] != nil && tag.attributes["id"] != nil {
                    metadata.metaAttributes.append(Meta(id: tag.attributes["id"]!, property: tag.attributes["property"]!, value: tag.value ?? ""))
                }
                
                if tag.attributes["property"] != nil {
                    metadata.metaAttributes.append(Meta(property: tag.attributes["property"]!, value: tag.value != nil ? tag.value! : "", refines: tag.attributes["refines"] != nil ? tag.attributes["refines"] : nil))
                }

            }
        }
        
        return metadata
    }
    
    /**
     Read and parse <spine>.
    */
    fileprivate func readSpine(_ tags: [AEXMLElement]) -> FRSpine {
        let spine = FRSpine()
        
        for tag in tags {
            let idref = tag.attributes["idref"]!
            var linear = true
            
            if tag.attributes["linear"] != nil {
                linear = tag.attributes["linear"] == "yes" ? true : false
            }
            
            if book.resources.containsById(idref) {
                spine.spineReferences.append(Spine(resource: book.resources.getById(idref)!, linear: linear))
            }
        }
        return spine
    }
    
    /**
     Add skip to backup file.
    */
    fileprivate func addSkipBackupAttributeToItemAtURL(_ URL: Foundation.URL) -> Bool {
        assert(FileManager.default.fileExists(atPath: URL.path))
        
        do {
            try (URL as NSURL).setResourceValue(true, forKey: URLResourceKey.isExcludedFromBackupKey)
            return true
        } catch let error as NSError {
            print("Error excluding \(URL.lastPathComponent) from backup \(error)")
            return false
        }
    }
    
    // MARK: - SSZipArchive delegate
    
    func zipArchiveWillUnzipArchive(atPath path: String, zipInfo: unz_global_info) {
        if shouldRemoveEpub {
            do {
                try FileManager.default.removeItem(atPath: epubPathToRemove!)
            } catch let error as NSError {
                print(error)
            }
        }
    }
}
