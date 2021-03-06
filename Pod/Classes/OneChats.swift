//
//  OneChats.swift
//  OneChat
//
//  Created by Paul on 04/03/2015.
//  Copyright (c) 2015 ProcessOne. All rights reserved.
//
//  Bugs fixed by Orkhan Alizade 24/11/2015

import Foundation
import XMPPFramework

public class OneChats: NSObject, NSFetchedResultsControllerDelegate {
	
	var chatList = NSMutableArray()
	var chatListBare = NSMutableArray()
	
	// MARK: Class function
	class var sharedInstance : OneChats {
		struct OneChatsSingleton {
			static let instance = OneChats()
		}
		return OneChatsSingleton.instance
	}
	
	public class func getChatsList() -> NSArray {
		if 0 == sharedInstance.chatList.count {
			if let chatList: NSMutableArray = sharedInstance.getActiveUsersFromCoreDataStorage() as? NSMutableArray {//NSUserDefaults.standardUserDefaults().objectForKey("openChatList")
				chatList.enumerateObjectsUsingBlock({ (jidStr, index, finished) -> Void in
					OneChats.sharedInstance.getUserFromXMPPCoreDataObject(jidStr: jidStr as! String)
					
					if let user = OneRoster.userFromRosterForJID(jid: jidStr as! String) {
						OneChats.sharedInstance.chatList.addObject(user)
					}
				})
			}
		}
		return sharedInstance.chatList
	}
	
	private func getActiveUsersFromCoreDataStorage() -> NSArray? {
		let moc = OneMessage.sharedInstance.xmppMessageStorage?.mainThreadManagedObjectContext
		let entityDescription = NSEntityDescription.entityForName("XMPPMessageArchiving_Message_CoreDataObject", inManagedObjectContext: moc!)
		let request = NSFetchRequest()
		let predicateFormat = "streamBareJidStr like %@ "
		
		if let predicateString = NSUserDefaults.standardUserDefaults().stringForKey("kXMPPmyJID") {
			let predicate = NSPredicate(format: predicateFormat, predicateString)
			request.predicate = predicate
			request.entity = entityDescription
			
			do {
				let results = try moc?.executeFetchRequest(request)
				var _: XMPPMessageArchiving_Message_CoreDataObject
				let archivedMessage = NSMutableArray()
				
				for message in results! {
					var element: DDXMLElement!
					do {
						element = try DDXMLElement(XMLString: message.messageStr)
					} catch _ {
						element = nil
					}
					let sender: String
					
					if element.attributeStringValueForName("to") != NSUserDefaults.standardUserDefaults().stringForKey("kXMPPmyJID")! && !(element.attributeStringValueForName("to") as NSString).containsString(NSUserDefaults.standardUserDefaults().stringForKey("kXMPPmyJID")!) {
						sender = element.attributeStringValueForName("to")
						if !archivedMessage.containsObject(sender) {
							archivedMessage.addObject(sender)
						}
					}
				}
				return archivedMessage
			} catch _ {
			}
		}
		return nil
	}
	
	private func getUserFromXMPPCoreDataObject(jidStr jidStr: String) {
		let moc = OneRoster.sharedInstance.managedObjectContext_roster() as NSManagedObjectContext?
		let entity = NSEntityDescription.entityForName("XMPPUserCoreDataStorageObject", inManagedObjectContext: moc!)
		let fetchRequest = NSFetchRequest()
		
		fetchRequest.entity = entity
		
		var predicate: NSPredicate
		
		if OneChat.sharedInstance.xmppStream == nil {
			predicate = NSPredicate(format: "jidStr == %@", jidStr)
		} else {
			predicate = NSPredicate(format: "jidStr == %@ AND streamBareJidStr == %@", jidStr, NSUserDefaults.standardUserDefaults().stringForKey("kXMPPmyJID")!)
		}
		
		fetchRequest.predicate = predicate
		fetchRequest.fetchLimit = 1
	}
	
	
	public class func knownUserForJid(jidStr jidStr: String) -> Bool {
		if sharedInstance.chatList.containsObject(OneRoster.userFromRosterForJID(jid: jidStr)!) {
			return true
		} else {
			return false
		}
	}
	
	public class func addUserToChatList(jidStr jidStr: String) {
		if !knownUserForJid(jidStr: jidStr) {
			sharedInstance.chatList.addObject(OneRoster.userFromRosterForJID(jid: jidStr)!)
			sharedInstance.chatListBare.addObject(jidStr)
		}
	}
	
	public class func removeUserAtIndexPath(indexPath: NSIndexPath) {
		let user = OneChats.getChatsList().objectAtIndex(indexPath.row) as! XMPPUserCoreDataStorageObject
		
		sharedInstance.removeMyUserActivityFromCoreDataStorageWith(user: user)
		sharedInstance.removeUserActivityFromCoreDataStorage(user: user)
		removeUserFromChatList(user: user)
	}
	
	public class func removeUserFromChatList(user user: XMPPUserCoreDataStorageObject) {
		if sharedInstance.chatList.containsObject(user) {
			sharedInstance.chatList.removeObjectIdenticalTo(user)
			sharedInstance.chatListBare.removeObjectIdenticalTo(user.jidStr)
		}
	}
	
	func removeUserActivityFromCoreDataStorage(user user: XMPPUserCoreDataStorageObject) {
		let moc = OneMessage.sharedInstance.xmppMessageStorage?.mainThreadManagedObjectContext
		let entityDescription = NSEntityDescription.entityForName("XMPPMessageArchiving_Message_CoreDataObject", inManagedObjectContext: moc!)
		let request = NSFetchRequest()
		let predicateFormat = "bareJidStr like %@ "
		
		let predicate = NSPredicate(format: predicateFormat, user.jidStr)
		request.predicate = predicate
		request.entity = entityDescription
		
		do {
			let results = try moc?.executeFetchRequest(request)
			for message in results! {
				moc?.deleteObject(message as! NSManagedObject)
			}
			
			do {
                		try moc?.save()
            		} catch let error {
                		print(error)
            		}
		} catch _ {
		}
	}
	
	func removeMyUserActivityFromCoreDataStorageWith(user user: XMPPUserCoreDataStorageObject) {
		let moc = OneMessage.sharedInstance.xmppMessageStorage?.mainThreadManagedObjectContext
		let entityDescription = NSEntityDescription.entityForName("XMPPMessageArchiving_Message_CoreDataObject", inManagedObjectContext: moc!)
		let request = NSFetchRequest()
		let predicateFormat = "streamBareJidStr like %@ "
		
		if let predicateString = NSUserDefaults.standardUserDefaults().stringForKey("kXMPPmyJID") {
			let predicate = NSPredicate(format: predicateFormat, predicateString)
			request.predicate = predicate
			request.entity = entityDescription
			
			do {
				let results = try moc?.executeFetchRequest(request)
				for message in results! {
					var element: DDXMLElement!
					do {
						element = try DDXMLElement(XMLString: message.messageStr)
					} catch _ {
						element = nil
					}
					
					if element.attributeStringValueForName("to") != NSUserDefaults.standardUserDefaults().stringForKey("kXMPPmyJID")! && !(element.attributeStringValueForName("to") as NSString).containsString(NSUserDefaults.standardUserDefaults().stringForKey("kXMPPmyJID")!) {
						if element.attributeStringValueForName("to") == user.jidStr {
							moc?.deleteObject(message as! NSManagedObject)
						}
					}
					
					do {
                				try moc?.save()
            				} catch let error {
                				print(error)
            				}
				}
			} catch _ {
			}
		}
	}
	
	// Mark: Will show "No recent chats" on OpenChatsTableViewController
	public class func noRecentChats() -> UIView {
        	var noRecentChats = UILabel()
        
        	if sharedInstance.getActiveUsersFromCoreDataStorage()?.count == 0 {
        	    let width = UIScreen.mainScreen().bounds.width
        	    let height = UIScreen.mainScreen().bounds.height
            
        	    noRecentChats = UILabel(frame: CGRectMake((width - 140) / 2, (height - 25 - 120) / 2, 140, 50))
        	    noRecentChats.text = "No recent chats"
        	    noRecentChats.textAlignment = .Center
        	    noRecentChats.textColor = UIColor(red: 153/255, green: 153/255, blue: 153/255, alpha: 0.5)
        	}
        	return noRecentChats
    	}
}
