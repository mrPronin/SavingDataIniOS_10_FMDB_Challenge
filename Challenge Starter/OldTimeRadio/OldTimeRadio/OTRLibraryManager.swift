
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
    var sqliteDB: COpaquePointer = nil
    var dbUrl: NSURL? = nil
    
    do {
      let baseUrl = try fileManager.URLForDirectory(.DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: false)
      dbUrl = baseUrl.URLByAppendingPathComponent("swift.sqlite")
    } catch {
      print(error)
    }
    
    if let dbUrl = dbUrl {
      
      let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE
      sqlite3_open_v2(dbUrl.absoluteString.cStringUsingEncoding(NSUTF8StringEncoding)!, &sqliteDB, flags, nil)
      
      let sqlStatements = ["CREATE TABLE if not exists Sites (SiteID integer primary key autoincrement, Name text, Address text, IsFree BOOLEAN, IsMembershipRequired BOOLEAN);",
                           "CREATE TABLE if not exists Shows (ShowID integer primary key autoincrement, Title text, Thumbnail text, Description text);",
                           "CREATE TABLE if not exists Episodes (EpisodeID integer primary key autoincrement, ShowID int, Title text, BroadcastDate date, FileLocation text);",
                           "CREATE TABLE if not exists Favorites (FavoriteID integer primary key autoincrement, EpisodeID integer, Note text, FavoriteDate date);"]
      
      for sql in sqlStatements {
        let errMsg: UnsafeMutablePointer<UnsafeMutablePointer<Int8>> = nil
        sqlite3_exec(sqliteDB, sql, nil, nil, errMsg)
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

              var statement: COpaquePointer = nil
              sqlite3_prepare(sqliteDB, insertSql, -1, &statement, nil)
              sqlite3_step(statement)
              sqlite3_finalize(statement)
            }
          }
          
          if let favorites = otrData["Favorites"] as? [[String : AnyObject]] {
            for favorite in favorites {
              let episodeId = favorite["Episode Id"] as! Int
              let note = favorite["Note"] as! String
              let date = favorite["Favorite Date"] as! NSDate
              let insertSql = "insert into Favorites (EpisodeID, Note, FavoriteDate) values (\(episodeId), '\(note)', '\(date)');"
              
              var statement: COpaquePointer = nil
              sqlite3_prepare(sqliteDB, insertSql, -1, &statement, nil)
              sqlite3_step(statement)
              sqlite3_finalize(statement)
            }
          }
          
          if let episodes = otrData["Episodes"] as? [[String : AnyObject]] {
            for episode in episodes {
              let showId = episode["Show Id"] as! Int
              let title = episode["Title"] as! String
              let broadcastDate = episode["Broadcast Date"] as! NSDate
              let fileLocation = episode["File Location"] as! String
              let insertSql = "insert into Episodes (ShowID, Title, BroadcastDate, FileLocation) values (\(showId), '\(title)', '\(broadcastDate)', '\(fileLocation)');"
              
              var statement: COpaquePointer = nil
              sqlite3_prepare(sqliteDB, insertSql, -1, &statement, nil)
              sqlite3_step(statement)
              sqlite3_finalize(statement)
            }
          }
          
          if let shows = otrData["Shows"] as? [[String : AnyObject]] {
            for show in shows {
              let title = show["Title"] as! String
              let thumbnail = show["Thumbnail"] as! String
              let description = show["Description"] as! String
              
              let insertSql = "insert into Shows (Title, Thumbnail, Description) values ('\(title)', '\(thumbnail)', '\(description)');"
              
              var statement: COpaquePointer = nil
              sqlite3_prepare(sqliteDB, insertSql, -1, &statement, nil)
              sqlite3_step(statement)
              sqlite3_finalize(statement)
            }
          }
          sqlite3_close(sqliteDB)
        } catch {
          print(error)
        }
      }
      
    }
    
  }
  
  func initializeLibrary() {
    let fileManager = NSFileManager.defaultManager()
    var sqliteDB: COpaquePointer = nil
    var dbUrl: NSURL? = nil
    
    do {
      let baseUrl = try fileManager.URLForDirectory(.DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: false)
      dbUrl = baseUrl.URLByAppendingPathComponent("swift.sqlite")
      print(dbUrl)
    } catch {
      print(error)
    }
    
    if let dbUrl = dbUrl {
      
      let flags = SQLITE_OPEN_READWRITE
      sqlite3_open_v2(dbUrl.absoluteString.cStringUsingEncoding(NSUTF8StringEncoding)!, &sqliteDB, flags, nil)
      
      var sql = "select * from Shows"
      var showSelect: COpaquePointer = nil
      if sqlite3_prepare_v2(sqliteDB, sql, -1, &showSelect, nil) == SQLITE_OK {
          while sqlite3_step(showSelect) == SQLITE_ROW {
            let showId = Int(sqlite3_column_int(showSelect, 0))
            let title = UnsafePointer<CChar>(sqlite3_column_text(showSelect, 1))
            let fileName = UnsafePointer<CChar>(sqlite3_column_text(showSelect, 2))
            let note = UnsafePointer<CChar>(sqlite3_column_text(showSelect, 3))
            let titleString = String.fromCString(title)
            let fileNameString = String.fromCString(fileName)
            let noteString = String.fromCString(note)
            let show = OTRShow(title: titleString!, thumbnailFileName: fileNameString!, showDescription: noteString!, showId: showId)
            otrShows.append(show)
        }
      }
      sqlite3_finalize(showSelect)
      
      sql = "select * from Episodes"
      var episodeSelect: COpaquePointer = nil
      if sqlite3_prepare_v2(sqliteDB, sql, -1, &episodeSelect, nil) == SQLITE_OK {
        while sqlite3_step(episodeSelect) == SQLITE_ROW {
          let episodeId = Int(sqlite3_column_int(episodeSelect, 0))
          let showId = Int(sqlite3_column_int(episodeSelect, 1))
          let title = UnsafePointer<CChar>(sqlite3_column_text(episodeSelect, 2))
          let broadcastDate = UnsafePointer<CChar>(sqlite3_column_text(episodeSelect, 3))
          let fileName = UnsafePointer<CChar>(sqlite3_column_text(episodeSelect, 4))
          
          let titleString = String.fromCString(title)
          let broadcastDateString = String.fromCString(broadcastDate)
          let fileNameString = String.fromCString(fileName)
          
          print(titleString)
          
          let dateFormatter = NSDateFormatter()
          dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss +0000"
          let date = dateFormatter.dateFromString(broadcastDateString!)
          
          for show in otrShows {
            if show.showId == showId {
              let episode = OTREpisode(title: titleString!, parentShow: show, broadcastDate: date!, episodeId: episodeId, fileLocation: fileNameString!)
              otrEpisodes.append(episode)
              break
            }
          }
        }
      }
      sqlite3_finalize(episodeSelect)
      
      sql = "select * from Favorites"
      var favoriteSelect: COpaquePointer = nil
      if sqlite3_prepare_v2(sqliteDB, sql, -1, &favoriteSelect, nil) == SQLITE_OK {
        while sqlite3_step(favoriteSelect) == SQLITE_ROW {
          let episodeId = Int(sqlite3_column_int(favoriteSelect, 1))
          let note = UnsafePointer<CChar>(sqlite3_column_text(favoriteSelect, 2))
          let favoriteDate = UnsafePointer<CChar>(sqlite3_column_text(favoriteSelect, 3))
          
          let noteString = String.fromCString(note)
          let favoriteDateString = String.fromCString(favoriteDate)
          
          let dateFormatter = NSDateFormatter()
          dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss +0000"
          let date = dateFormatter.dateFromString(favoriteDateString!)
          
          for episode in otrEpisodes {
            if episode.episodeId == episodeId {
              let favorite = OTRFavorite(episode: episode, favoriteDate: date!, note: noteString!)
              otrFavorites.append(favorite)
            }
          }
        }
      }
      sqlite3_finalize(favoriteSelect)
      
      sql = "select * from Sites"
      var siteSelect: COpaquePointer = nil
      if sqlite3_prepare_v2(sqliteDB, sql, -1, &siteSelect, nil) == SQLITE_OK {
        while sqlite3_step(siteSelect) == SQLITE_ROW {
          let name = UnsafePointer<CChar>(sqlite3_column_text(siteSelect, 0))
          let address = UnsafePointer<CChar>(sqlite3_column_text(siteSelect, 1))
          let isFree = Int(sqlite3_column_int(siteSelect, 2))
          let isMembershipRequired = Int(sqlite3_column_int(siteSelect, 3))
          
          let nameString = String.fromCString(name)
          let addressString = String.fromCString(address)
          
          var isFreeBool = false
          if isFree == 0 {
            isFreeBool = true
          }
          
          var isMembershipRequiredBool = false
          if isMembershipRequired == 0 {
            isMembershipRequiredBool = true
          }
          
          let site = OTRSite(name: nameString!, address: addressString!, isFree: isFreeBool, isMembershipRequired: isMembershipRequiredBool)
          otrSites.append(site)
        }
        
      }
      sqlite3_finalize(siteSelect)
      
      
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