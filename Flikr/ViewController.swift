//
//  ViewController.swift
//  Flikr
//
//  Created by Garima Dhakal on 12/14/16.
//  Copyright © 2016 Garima Dhakal. All rights reserved.
//

import UIKit
import ArcGIS

class ViewController: UIViewController, UISearchBarDelegate, AGSGeoViewTouchDelegate, AGSPopupsViewControllerDelegate {
    private var pointGraphicOverlay: AGSGraphicsOverlay!

    @IBOutlet weak var mapView: AGSMapView!
    @IBOutlet weak var searchBar: UISearchBar!
    private var map: AGSMap!
    private var extent: AGSEnvelope!
    
    private var popupsVC:AGSPopupsViewController!
    
    private var popupInfo: AGSPopupDefinition!
    private var mediaDictionary: NSMutableDictionary!
    
    private var featureCollectionTable: AGSFeatureCollectionTable!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let vectorTiledLayer = AGSArcGISVectorTiledLayer.init(url: URL(string: "http://www.arcgis.com/home/item.html?id=4e1133c28ac04cca97693cf336cd49ad")!)
        self.map = AGSMap(basemap: AGSBasemap(baseLayer: vectorTiledLayer))
        self.mapView.map = self.map
        
        self.pointGraphicOverlay = AGSGraphicsOverlay()
        
        self.mapView.touchDelegate = self
        self.searchBar.delegate = self
    }
    
    func convertDataToObject(value: Data) {
        let jsonData = value as Data
        do {
            guard let parsedResult = try JSONSerialization.jsonObject(with: jsonData, options: .allowFragments) as? NSDictionary else {
                return
            }
            let items = parsedResult.object(forKey: "items") as! NSArray
            self.addGraphics(arrayOfItems: items)
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }
    
    func addGraphics (arrayOfItems: NSArray) {
        let pictureMarkerSymbol = AGSPictureMarkerSymbol.init(image: #imageLiteral(resourceName: "flickr.png"))
        pictureMarkerSymbol.height = 20
        pictureMarkerSymbol.width = 20
        
        let graphicsArray = NSMutableArray()
        var arrayOfPoints = [AGSPoint]()
        for item in arrayOfItems {
            let media = (item as AnyObject).object(forKey: "media") as! NSDictionary
            let sourceUrl = media.object(forKey: "m") as! String
            let linkUrl = (item as AnyObject).object(forKey: "link") as! String
            
            let title = (item as AnyObject).object(forKey: "title")
            
            let htmlDescriptionText = (item as AnyObject).object(forKey:"description") as! String
            let description = try! NSAttributedString(
                data: htmlDescriptionText.data(using: String.Encoding.unicode, allowLossyConversion: false)!,
                options: [ NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType],
                documentAttributes: nil)
            
            let author = (item as AnyObject).object(forKey: "author") as! String
            
            let longStr = (item as AnyObject).object(forKey: "longitude") as! String
            let latStr = (item as AnyObject).object(forKey:"latitude") as! String
            let longitude = Double(longStr)
            let latitude = Double(latStr)
            
            let createdDate = (item as AnyObject).object(forKey:"date_taken")
            let dateFormatter = DateFormatter.init()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZ"
            let date = dateFormatter.date(from: createdDate as! String)
            
            let point = AGSPoint(x: longitude!, y: latitude!, spatialReference: AGSSpatialReference.init(wkid: 4326))
            arrayOfPoints.append(point)
            
            var attributes = Dictionary<String, Any>()
            attributes["title"] = title as! String
            attributes["description"] = description.string 
            attributes["sourceUrl"] = sourceUrl
            attributes["linkUrl"] = linkUrl
            attributes["date"] = date as Date?
            attributes["author"] = author
        
            let graphic = AGSGraphic.init(geometry: point, symbol: pictureMarkerSymbol, attributes: attributes)
            graphicsArray.add(graphic)
            
        }
        
        self.pointGraphicOverlay.graphics.addObjects(from: (graphicsArray as [AnyObject]))
        self.mapView.graphicsOverlays.add(self.pointGraphicOverlay)
        
        let multipoint = AGSMultipointBuilder.init(points: arrayOfPoints)
        let envelop = multipoint.extent
        let viewpoint = AGSViewpoint.init(targetExtent: envelop)

        self.mapView.setViewpoint(viewpoint)
        
    }
    
    // MARK: AGSGeoViewTouchDelegate methods
    
    func geoView(_ geoView: AGSGeoView, didTapAtScreenPoint screenPoint: CGPoint, mapPoint: AGSPoint) {
        let tolerance:Double = 5
        
        self.mapView.identify(self.pointGraphicOverlay, screenPoint: screenPoint, tolerance: tolerance, returnPopupsOnly: false, maximumResults: 10) { (result: AGSIdentifyGraphicsOverlayResult) -> Void in
            if let error = result.error {
                print("error while identifying :: \(error.localizedDescription)")
            } else {
                if(result.graphics.count > 0) {
                    var popupArray = [AGSPopup]()
                    for graphic in result.graphics {
                        let popupInfo = AGSPopupDefinition()
                        popupInfo.allowDelete = false
                        popupInfo.allowEdit = false
                        popupInfo.allowEditGeometry = false
                        
                        var popupFields = [AGSPopupField]()
                        
                        let dateField = AGSPopupField()
                        dateField.fieldName = "date"
                        dateField.label = "Date"
                        popupFields.append(dateField)
                        
                        let messageField = AGSPopupField()
                        messageField.fieldName = "title"
                        messageField.label = "Title"
                        popupFields.append(messageField)
                        
                        let descriptionField = AGSPopupField()
                        descriptionField.fieldName = "description"
                        descriptionField.label = "Description"
                        popupFields.append(descriptionField)
                        
                        let authorField = AGSPopupField()
                        authorField.fieldName = "author"
                        authorField.label = "Author"
                        popupFields.append(authorField)
                        
                        popupInfo.fields = popupFields
                        let popupMedia = AGSPopupMedia()
                        popupMedia.type = AGSPopupMediaType.image
                        
                        //popupMedia.caption = captionText.string
                        
                        let popupMediaValue = AGSPopupMediaValue()
                        popupMediaValue.link = graphic.attributes.object(forKey: "linkUrl") as! String
                        popupMediaValue.source = graphic.attributes.object(forKey: "sourceUrl") as! String
                        popupMedia.value = popupMediaValue
                        
                        popupInfo.media = [popupMedia]
                        let popup = AGSPopup.init(geoElement: graphic, popupDefinition: popupInfo)
            
                        popupArray.append(popup)
                    }
                    
                    self.popupsVC = AGSPopupsViewController.init(popups: popupArray, containerStyle: .navigationBar)
                    self.popupsVC.delegate = self
                    
                    //show popup view controller
                    self.present(self.popupsVC, animated: true, completion: nil)
                } else {
                    print ("no results found")
                }
            }
        }
    }
    
    // MARK: AGSPopupsViewControllerDelegate methods
    
    func popupsViewControllerDidFinishViewingPopups(_ popupsViewController: AGSPopupsViewController) {
        //dismiss the popups view controller
        self.dismiss(animated: true, completion:nil)
        self.popupsVC = nil
    }
    
    //MARK: UISearchBarDelegate methods
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        let tag = self.searchBar.text! as String
        let createUrl = "https://api.flickr.com/services/feeds/geo?tagmode=all&tags=\(tag)&format=json&nojsoncallback=1"
        
        let flickrURL = URL(string: createUrl)
        let session = URLSession.shared
        
        (session.dataTask(with: flickrURL!, completionHandler: { (data: Data?, response, error) -> Void in
            
            if(data == nil) {
                print("data is nil")
            } else {
                self.convertDataToObject(value: data!)
            }
        })).resume()
        
    }
    
}

