
//
//  OTRLibrary.swift
//  OldTimeRadio
//
//  Created by Brian on 11/28/15.
//  Copyright © 2015 Razeware LLC. All rights reserved.
//

import Foundation

class OTRLibraryManager {
    
    static let sharedInstance = OTRLibraryManager()
    private init() {
    }
    
    var otrSites = [OTRSite]()
    var otrShows = [OTRShow]()
    var otrEpisodes = [OTREpisode]()
    var otrFavorites = [OTRFavorite]()
    
    
    
    func buildLibraryFromPlist() {
        
        let fileManager = NSFileManager.defaultManager()
        var dbUrl: NSURL? = nil
        
        do {
            let baseUrl = try fileManager.URLForDirectory(.DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: false)
            dbUrl = baseUrl.URLByAppendingPathComponent("swift.sqlite")
        } catch {
            print(error)
        }
        
        if let dbUrl = dbUrl {
            let fmdb = FMDatabase(path: dbUrl.absoluteString)
            fmdb.open()
            
            let sqlStatements = ["CREATE TABLE if not exists Sites (SiteID integer primary key autoincrement, Name text, Address text, IsFree BOOLEAN, IsMembershipRequired BOOLEAN);",
                                 "CREATE TABLE if not exists Shows (ShowID integer primary key autoincrement, Title text, Thumbnail text, Description text);",
                                 "CREATE TABLE if not exists Episodes (EpisodeID integer primary key autoincrement, ShowID int, Title text, BroadcastDate date, FileLocation text);",
                                 "CREATE TABLE if not exists Favorites (FavoriteID integer primary key autoincrement, EpisodeID integer, Note text, FavoriteDate date);"]
            
            for sql in sqlStatements {
                try! fmdb.executeUpdate(sql, values: nil)
            }
            
            guard let otrPlistUrl = NSBundle.mainBundle().URLForResource("old_time_radio", withExtension: "plist") else {
                return
            }
            if let plistData = NSData(contentsOfURL: otrPlistUrl) {
                var format = NSPropertyListFormat.XMLFormat_v1_0
                do {
                    let otrData = try NSPropertyListSerialization.propertyListWithData(plistData, options: .Immutable, format: &format)
                    
                    if let sites = otrData["Sites"] as? [[String : AnyObject]] {
                        for site in sites {
                            let name = site["Name"] as! String
                            let address = site["Address"] as! String
                            let isFree = site["Is Free"] as! Bool
                            let membershipRequired = site["Membership Required"] as! Bool
                            let insertSql = "insert into Sites (Name, Address, IsFree, IsMembershipRequired) values ('\(name)', '\(address)', \(boolToInt(isFree)), \(boolToInt(membershipRequired)));"
                            try! fmdb.executeUpdate(insertSql, values: nil)
                        }
                    }
                    
                    if let favorites = otrData["Favorites"] as? [[String : AnyObject]] {
                        for favorite in favorites {
                            let episodeId = favorite["Episode Id"] as! Int
                            let note = favorite["Note"] as! String
                            let date = favorite["Favorite Date"] as! NSDate
                            let insertSql = "insert into Favorites (EpisodeID, Note, FavoriteDate) values (\(episodeId), '\(note)', '\(date)');"
                            
                            try! fmdb.executeUpdate(insertSql, values: nil)
                        }
                    }
                    
                    if let episodes = otrData["Episodes"] as? [[String : AnyObject]] {
                        for episode in episodes {
                            let showId = episode["Show Id"] as! Int
                            let title = episode["Title"] as! String
                            let broadcastDate = episode["Broadcast Date"] as! NSDate
                            let fileLocation = episode["File Location"] as! String
                            let insertSql = "insert into Episodes (ShowID, Title, BroadcastDate, FileLocation) values (\(showId), '\(title)', '\(broadcastDate)', '\(fileLocation)');"
                            
                            try! fmdb.executeUpdate(insertSql, values: nil)
                        }
                    }
                    
                    if let shows = otrData["Shows"] as? [[String : AnyObject]] {
                        for show in shows {
                            let title = show["Title"] as! String
                            let thumbnail = show["Thumbnail"] as! String
                            let description = show["Description"] as! String
                            
                            let insertSql = "insert into Shows (Title, Thumbnail, Description) values ('\(title)', '\(thumbnail)', '\(description)');"
                            
                            try! fmdb.executeUpdate(insertSql, values: nil)
                        }
                    }
                    fmdb.close()
                } catch {
                    print(error)
                }
            }
            
        }
        
    }
    
    func initializeLibrary() {
        let fileManager = NSFileManager.defaultManager()
        var dbUrl: NSURL? = nil
        
        do {
            let baseUrl = try fileManager.URLForDirectory(.DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: false)
            dbUrl = baseUrl.URLByAppendingPathComponent("swift.sqlite")
            print(dbUrl)
        } catch {
            print(error)
        }
        
        if let dbUrl = dbUrl {
            
            let fmdb = FMDatabase(path: dbUrl.absoluteString)
            fmdb.open()
            
            var sql = "select * from Shows"
            var fmresult = fmdb.executeQuery(sql, withParameterDictionary: nil)
            while fmresult.next() {
                let showId = Int(fmresult.intForColumn("ShowID"))
                let titleString = fmresult.stringForColumn("Title")
                let fileNameString = fmresult.stringForColumn("Thumbnail")
                let noteString = fmresult.stringForColumn("Description")
                let show = OTRShow(title: titleString!, thumbnailFileName:
                    fileNameString!, showDescription: noteString!, showId: showId)
                otrShows.append(show)
            }
            
            sql = "select * from Episodes"
            fmresult = fmdb.executeQuery(sql, withParameterDictionary: nil)
            while fmresult.next() {
                let episodeId = Int(fmresult.intForColumn("episodeId"))
                let showId = Int(fmresult.intForColumn("showId"))
                let titleString = fmresult.stringForColumn("Title")
                let date = fmresult.dateForColumn("BroadcastDate")
                let fileLocation = fmresult.stringForColumn("FileLocation")
                
                for show in otrShows {
                    if show.showId == showId {
                        let episode = OTREpisode(title: titleString!, parentShow: show, broadcastDate: date!, episodeId: episodeId, fileLocation: fileLocation!)
                        otrEpisodes.append(episode)
                        break
                    }
                }
            }
            
            sql = "select * from Favorites"
            fmresult = fmdb.executeQuery(sql, withParameterDictionary: nil)
            while fmresult.next() {
                let episodeId = Int(fmresult.intForColumn("episodeId"))
                let note = fmresult.stringForColumn("note")
                let favoriteDate = fmresult.dateForColumn("FavoriteDate")
                
                for episode in otrEpisodes {
                    if episode.episodeId == episodeId {
                        let favorite = OTRFavorite(episode: episode, favoriteDate: favoriteDate!, note: note!)
                        otrFavorites.append(favorite)
                    }
                }
            }
            
            sql = "select * from Sites"
            fmresult = fmdb.executeQuery(sql, withParameterDictionary: nil)
            while fmresult.next() {
                let name = fmresult.stringForColumn("name")
                let address = fmresult.stringForColumn("address")
                let isFree = fmresult.boolForColumn("IsFree")
                let isMembershipRequired = fmresult.boolForColumn("IsMembershipRequired")
                
                let site = OTRSite(name: name!, address: address!, isFree: isFree, isMembershipRequired: isMembershipRequired)
                otrSites.append(site)
            }
            fmdb.close()
        }
    }
    
    func loadFromPlist() {
        
        guard let otrPlistUrl = NSBundle.mainBundle().URLForResource("old_time_radio", withExtension: "plist") else {
            return
        }
        if let plistData = NSData(contentsOfURL: otrPlistUrl) {
            var format = NSPropertyListFormat.XMLFormat_v1_0
            do {
                let otrData = try NSPropertyListSerialization.propertyListWithData(plistData, options: .Immutable, format: &format)
                
                if let sites = otrData["Sites"] as? [[String : AnyObject]] {
                    for site in sites {
                        let name = site["Name"] as! String
                        let address = site["Address"] as! String
                        let isFree = site["Is Free"] as! Bool
                        let membershipRequired = site["Membership Required"] as! Bool
                        
                        let otrSite = OTRSite(name: name, address: address, isFree: isFree, isMembershipRequired: membershipRequired)
                        otrSites.append(otrSite)
                    }
                }
                if let shows = otrData["Shows"] as? [[String : AnyObject]] {
                    for show in shows {
                        let showId = show["Id"] as! Int
                        let title = show["Title"] as! String
                        let thumbnail = show["Thumbnail"] as! String
                        let description = show["Description"] as! String
                        
                        let otrShow = OTRShow(title: title, thumbnailFileName: thumbnail, showDescription: description, showId: showId)
                        otrShows.append(otrShow)
                    }
                }
                
                if let episodes = otrData["Episodes"] as? [[String : AnyObject]] {
                    for episode in episodes {
                        let showId = episode["Show Id"] as! Int
                        let episodeId = episode["Episode Id"] as! Int
                        let title = episode["Title"] as! String
                        let broadcastDate = episode["Broadcast Date"] as! NSDate
                        let fileLocation = episode["File Location"] as! String
                        
                        for show in otrShows {
                            if showId == show.showId {
                                let otrEpisode = OTREpisode(title: title, parentShow: show, broadcastDate: broadcastDate, episodeId: episodeId, fileLocation: fileLocation)
                                otrEpisodes.append(otrEpisode)
                                break
                            }
                        }
                        
                    }
                }
                
                if let favorites = otrData["Favorites"] as? [[String : AnyObject]] {
                    for favorite in favorites {
                        let episodeId = favorite["Episode Id"] as! Int
                        let note = favorite["Note"] as! String
                        let date = favorite["Favorite Date"] as! NSDate
                        for episode in otrEpisodes {
                            if episode.episodeId == episodeId {
                                let otrFavorite = OTRFavorite(episode: episode, favoriteDate: date, note: note)
                                otrFavorites.append(otrFavorite)
                                break
                            }
                        }
                    }
                }
                
            } catch {
                print(error)
            }
        }
        
    }
    
    func boolToInt(boolValue:Bool) -> Int {
        if boolValue == true {
            return 1
        }
        return 0
    }
    
    
}