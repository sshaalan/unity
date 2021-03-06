/* 
 * Unity - Communities
 * 
 * Community is critical to the student experience--but building community is 
 * just plain hard. Built on Communities and designed specifically for higher ed, 
 * Unity is a powerful networking tool to help you generate engagement and 
 * connect your campus.
 * 
 * Copyright (C) 2015 Motivis Learning Systems Inc.
 * 
 * This program is free software: you can redistribute it and/or modify 
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 * 
 * To contact Motivis Learning Systems Inc.
 * 25 Pelham Road
 * Salem, NH 03790
 * unity@motivislearning.com
 */

public without sharing class CommunityHelperWithoutSharing {
	public CommunityHelperWithoutSharing() {
		
	}
	public static String getCommunityGroupControl(Id chatterGroupId) {
		if (String.isBlank(chatterGroupId)) return null;
		if (!SObjectType.Community_Group_Control__c.isAccessible()) CommunityAccess.ThrowAccessException(SObjectType.Community_Group_Control__c);
		List<Community_Group_Control__c> gcList = [SELECT Id FROM Community_Group_Control__c WHERE Chatter_Group_ID__c = :chatterGroupId LIMIT 1];
		return gcList.isEmpty() ? null : gcList[0].Id;
	}
	
	public static List<User> getCommunityUsers(String querySearch, Integer queryLimit, List<String> queryFields, String sortColumn, Boolean isAscDirect) {
		String sortCol = String.isNotBlank(sortColumn) ? 'Name' : String.escapeSingleQuotes(sortColumn);
		String sortDir = isAscDirect ? 'ASC' : 'DESC';
		List<User> uList = new List<User>();
		try {
			querySearch = String.isNotBlank(querySearch) ? String.escapeSingleQuotes(querySearch) + '%' : '%%';
			String fieldsSting = '';
			if (queryFields != null) {
				for (String field : queryFields) {
					fieldsSting += ', Member.' + String.escapeSingleQuotes(field);
				}
			}
			String currentNetworkId = Network.getNetworkId();
			String currentUserId = UserInfo.getUserId();
			String queryNetworkMembers = 'SELECT Id, Member.Id, Member.Name' + fieldsSting + ' FROM NetworkMember'
					+ ' WHERE Member.isActive = true AND NetworkId = :currentNetworkId AND MemberId != :currentUserId'
					+ ' AND (Member.Name LIKE \'' + querySearch + '\' OR Member.LastName LIKE \''+querySearch+ '\' OR Member.FirstName LIKE \''+querySearch+ '\')'
					+ ' ORDER BY Member.' + sortCol + ' ' + sortDir + ' LIMIT :queryLimit';

			if (!SObjectType.NetworkMember.isAccessible()) CommunityAccess.ThrowAccessException(SObjectType.NetworkMember);
			List<NetworkMember> nmList = Database.query(queryNetworkMembers);
			for (NetworkMember nm : nmList) {
				uList.add((User)nm.Member);
			}
			if (Test.isRunningTest()) {
				String collectedFields = String.join(queryFields, ', ');
				String queryUsers = 'SELECT Id' + (String.isNotBlank(collectedFields) ? ', ' + collectedFields : '') + ', Name FROM User'
						+ ' WHERE isActive = true AND Id != :currentUserId'
						+ ' AND (FirstName LIKE :querySearch OR LastName LIKE :querySearch OR Name LIKE :querySearch)'
						+ ' ORDER BY ' + sortCol + ' ' + sortDir + ' LIMIT :queryLimit';

				if (!SObjectType.User.isAccessible()) CommunityAccess.ThrowAccessException(SObjectType.User);
				uList = Database.query(queryUsers);
			}
		}
		catch (Exception e) {
			System.debug(e);
		}
		return uList;
	}
	
	// used for CommunityNewsController
	public static String ImageLibFolder() {
		Community_Settings__c cs = Community_Settings__c.getInstance();
		if (String.isNotBlank(cs.Image_Library_Folder__c)) {
			List<sObject> folders = [SELECT Id, Name, DeveloperName FROM Folder where DeveloperName = :String.valueOf(cs.Image_Library_Folder__c)  Limit 1];
			return folders.size() > 0 ? folders[0].Id : null;
		}
		return null;
	}

// used for CommunityGroupFilesController
    public static FeedItem getFeedParentId(String contentTitle, String contentOwner, Datetime createdDate){
        return [SELECT Id, Type, ParentId, Title, CreatedById, CreatedDate 
                FROM FeedItem 
                WHERE Type = 'ContentPost' 
                    AND Title = :contentTitle 
                    AND CreatedById = :contentOwner 
                    AND (CreatedDate < :createdDate.addSeconds(5) AND CreatedDate > :createdDate.addSeconds(-5)) LIMIT 1];
	}

// used for CommunityFeedController
	public static List<User> getUsers(Set<String> usersIds){
		if (!SObjectType.User.isAccessible()) CommunityAccess.ThrowAccessException(SObjectType.User);
		return [SELECT Id, Name FROM User WHERE Id IN :usersIds];
	}

// used for CommunityFeedController
	public static List<Community_Group_Control__c> getGroups(Set<String> groupsIds){
		if (!SObjectType.Community_Group_Control__c.isAccessible()) CommunityAccess.ThrowAccessException(SObjectType.Community_Group_Control__c);
		return [SELECT Chatter_Group_ID__c, Name FROM Community_Group_Control__c WHERE Chatter_Group_ID__c IN :groupsIds];
	}

// used for CommunityHomeNotificationController
	public static List<FeedItem> getFeeds(Set<Id> controlsIds, String userId){
		String queryUserId = CommunityUtils.validateId(userId);
		return [SELECT Id, ParentId, Type, CommentCount, LinkUrl, LastModifiedDate, CreatedById, Visibility 
				FROM FeedItem
				WHERE ParentId IN :controlsIds 
				AND CreatedById != :queryUserId
				AND Visibility = 'AllUsers'
				LIMIT 10000];
		}

// used for CommunityGroupManageController
	public static Integer getOverallActivity(String chatterGroupId){
		String queryChatterGroupId = CommunityUtils.validateId(chatterGroupId);
		return [SELECT COUNT() FROM FeedItem WHERE ParentId = :queryChatterGroupId];
	}

	public static Integer getPostsThisWeek(String chatterGroupId){
		String queryChatterGroupId = CommunityUtils.validateId(chatterGroupId);
		return [SELECT COUNT() FROM FeedItem WHERE ParentId = :queryChatterGroupId AND CreatedDate = THIS_WEEK];
	}

	public static Integer getPostThisMonth(String chatterGroupId){
		String queryChatterGroupId = CommunityUtils.validateId(chatterGroupId);
		return [SELECT COUNT() FROM FeedItem WHERE ParentId = :queryChatterGroupId AND CreatedDate = THIS_MONTH];
	}

// used for CommunityGroupFilesController
	public static List<FeedItem> getFeeds(String chatterGroupId){
		String queryChatterGroupId = CommunityUtils.validateId(chatterGroupId);
		String fQuery = 'SELECT Id, CreatedById, CreatedBy.Name, ContentFileName, LastModifiedDate, RelatedRecordId FROM FeedItem';
		fQuery += ' WHERE Type = \'ContentPost\' AND ParentId = :queryChatterGroupId LIMIT 500';
		return Database.query(fQuery);
	}

// used for CommunityFeedController
	public static Attachment getAttachment(String attachId){
		if (!SObjectType.Attachment.isAccessible()) CommunityAccess.ThrowAccessException(SObjectType.Attachment);
		String queryAttachId = CommunityUtils.validateId(attachId);
		return [SELECT Id, Name, ContentType, Body, Description FROM Attachment WHERE Id = :queryAttachId LIMIT 1];
	}

	public static ConnectApi.GroupMembershipType membershipWOSH(String inUserId, String inGroupContolId, String inMode) {
		ConnectApi.GroupMembershipType resultType;
		Integer inmm = Integer.valueOf(inMode);
		if (!SObjectType.Community_Group_Control__c.isAccessible()) CommunityAccess.ThrowAccessException(SObjectType.Community_Group_Control__c);
		if (!SObjectType.CollaborationGroupMember.isAccessible()) CommunityAccess.ThrowAccessException(SObjectType.CollaborationGroupMember);
		String queryInGroupContolId = CommunityUtils.validateId(inGroupContolId);
		String queryInUserId = CommunityUtils.validateId(inUserId);
		Community_Group_Control__c cgc = [SELECT Id, Chatter_Group_ID__c FROM Community_Group_Control__c WHERE Id = :queryInGroupContolId];
		List<CollaborationGroupMember> cgmList = [SELECT Id, CollaborationRole FROM CollaborationGroupMember WHERE MemberId =:queryInUserId AND CollaborationGroupId =:cgc.Chatter_Group_ID__c];
		// 1 - Create Chatter Group Member
		// 2 - Delete Chatter Group Member
		if (inmm < 3) {
			if (inmm == 2) {
				// delete manager if exist
				if (!SObjectType.Community_Group_Manager__c.isAccessible()) CommunityAccess.ThrowAccessException(SObjectType.Community_Group_Manager__c);
				if (!SObjectType.EntitySubscription.isAccessible()) CommunityAccess.ThrowAccessException(SObjectType.EntitySubscription);
				List<Community_Group_Manager__c> cgmList2 = [SELECT Id FROM Community_Group_Manager__c WHERE Group_Manager_User__c =:queryInUserId AND Group_Control__c =:cgc.Id];
				List<EntitySubscription> esList2 = [SELECT Id FROM EntitySubscription WHERE ParentId = :cgc.Id AND SubscriberId = :queryInUserId LIMIT 1];
				//delete cgmList2;
				CommunityAccess.DeleteWithoutSharing(
					cgmList2,
					'CommunityHelperWithoutSharing.cls [membershipWOSH]'
				);
				//delete esList2;
				CommunityAccess.DeleteWithoutSharing(
					esList2,
					'CommunityHelperWithoutSharing.cls [membershipWOSH]'
				);
				if (cgmList.size() > 0 && cgmList[0].CollaborationRole == 'Admin') {
					cgmList[0].CollaborationRole = 'Standard';
					//update cgmList;
					CommunityAccess.UpdateWithoutSharing(
						cgmList,
						'CommunityHelperWithoutSharing.cls [membershipWOSH]',
						new List<Schema.DescribeFieldResult> {
							CollaborationGroupMember.CollaborationRole.getDescribe()
						}
					);
				}
				resultType = ConnectApi.GroupMembershipType.StandardMember;
				//
				//delete cgmList;
				CommunityAccess.DeleteWithoutSharing(
					cgmList,
					'CommunityHelperWithoutSharing.cls [membershipWOSH]'
				);
				resultType = ConnectApi.GroupMembershipType.NotAMember;
			}
			else if (cgmList.size() == 0) {
				if (!SObjectType.NetworkMember.isAccessible()) CommunityAccess.ThrowAccessException(SObjectType.NetworkMember);
				NetworkMember nm = Test.isRunningTest() ? new NetworkMember()
									: [SELECT Id, DefaultGroupNotificationFrequency FROM NetworkMember WHERE MemberId = :queryInUserId AND NetworkId = :Network.getNetworkId()];
				//insert 
				CollaborationGroupMember cgm = new CollaborationGroupMember(MemberId = inUserId, CollaborationGroupId = cgc.Chatter_Group_ID__c, NotificationFrequency = nm.DefaultGroupNotificationFrequency);
				CommunityAccess.InsertWithoutSharing(
					cgm,
					'CommunityHelperWithoutSharing.cls [membershipWOSH]',
					new List<Schema.DescribeFieldResult> {
						CollaborationGroupMember.MemberId.getDescribe(),
						CollaborationGroupMember.CollaborationGroupId.getDescribe(),
						CollaborationGroupMember.NotificationFrequency.getDescribe()
					}
				);
				resultType = ConnectApi.GroupMembershipType.StandardMember;
			}
		}
		// 3 - Create Group Manager
		// 4 - Delete Group Manager
		else if (inmm < 5) {
			if (!SObjectType.Community_Group_Manager__c.isAccessible()) CommunityAccess.ThrowAccessException(SObjectType.Community_Group_Manager__c);
			if (!SObjectType.EntitySubscription.isAccessible()) CommunityAccess.ThrowAccessException(SObjectType.EntitySubscription);
			List<Community_Group_Manager__c> cgmList2 = [SELECT Id FROM Community_Group_Manager__c WHERE Group_Manager_User__c =:queryInUserId AND Group_Control__c =:cgc.Id];
			List<EntitySubscription> esList2 = [SELECT Id FROM EntitySubscription WHERE ParentId = :cgc.Id AND SubscriberId = :queryInUserId LIMIT 1];
			if (inmm == 4) {
				//delete cgmList2;
				CommunityAccess.DeleteWithoutSharing(
					cgmList2,
					'CommunityHelperWithoutSharing.cls [membershipWOSH]'
				);
				//delete esList2;
				CommunityAccess.DeleteWithoutSharing(
					esList2,
					'CommunityHelperWithoutSharing.cls [membershipWOSH]'
				);
				if (cgmList.size() > 0 && cgmList[0].CollaborationRole == 'Admin') {
					cgmList[0].CollaborationRole = 'Standard';
					//update cgmList;
					CommunityAccess.UpdateWithoutSharing(
						cgmList,
						'CommunityHelperWithoutSharing.cls [membershipWOSH]',
						new List<Schema.DescribeFieldResult> {
							CollaborationGroupMember.CollaborationRole.getDescribe()
						}
					);
				}
				resultType = ConnectApi.GroupMembershipType.StandardMember;
			}
			else {
				if (cgmList.size() == 0) {
					if (!SObjectType.NetworkMember.isAccessible()) CommunityAccess.ThrowAccessException(SObjectType.NetworkMember);
					NetworkMember nm = [SELECT Id, DefaultGroupNotificationFrequency FROM NetworkMember WHERE MemberId = :queryInUserId AND NetworkId = :Network.getNetworkId()];
					//insert 
					CollaborationGroupMember cgm1 = new CollaborationGroupMember(MemberId = inUserId, CollaborationGroupId = cgc.Chatter_Group_ID__c, NotificationFrequency = nm.DefaultGroupNotificationFrequency);
					CommunityAccess.InsertWithoutSharing(
						cgm1,
						'CommunityHelperWithoutSharing.cls [membershipWOSH]',
						new List<Schema.DescribeFieldResult> {
							CollaborationGroupMember.MemberId.getDescribe(),
							CollaborationGroupMember.CollaborationGroupId.getDescribe(),
							CollaborationGroupMember.NotificationFrequency.getDescribe()
						}
					);
				}
				else if (cgmList[0].CollaborationRole == 'Standard') {
					cgmList[0].CollaborationRole = 'Admin';
					//update cgmList;
					CommunityAccess.UpdateWithoutSharing(
						cgmList,
						'CommunityHelperWithoutSharing.cls [membershipWOSH]',
						new List<Schema.DescribeFieldResult> {
							CollaborationGroupMember.CollaborationRole.getDescribe()
						}
					);
				}
				if (cgmList2.size() == 0) {
					//insert 
					Community_Group_Manager__c cgmn = new Community_Group_Manager__c(Group_Manager_User__c = inUserId, Group_Control__c = cgc.Id, Manager_Role__c = 'Manager');
					
					CommunityAccess.InsertWithoutSharing(
						cgmn,
						'CommunityHelperWithoutSharing.cls [membershipWOSH]',
						new List<Schema.DescribeFieldResult> {
							Community_Group_Manager__c.Group_Manager_User__c.getDescribe(),
							Community_Group_Manager__c.Group_Control__c.getDescribe(),
							Community_Group_Manager__c.Manager_Role__c.getDescribe()
						}
					);
				}
				if (esList2.size() == 0) {
					//insert 
					EntitySubscription es = new EntitySubscription(ParentId = cgc.Id, SubscriberId = inUserId, NetworkId = Network.getNetworkId());
					CommunityAccess.InsertWithoutSharing(
						es,
						'CommunityHelperWithoutSharing.cls [membershipWOSH]',
						new List<Schema.DescribeFieldResult> {
							EntitySubscription.ParentId.getDescribe(),
							EntitySubscription.SubscriberId.getDescribe()
						}
					);
				}
				resultType = ConnectApi.GroupMembershipType.GroupManager;
			}
		}
		// 5 - Create Join Private Group Request
		// 6 - Delete Join Private Group Request
		else if (inmm < 7) {
			if (!SObjectType.CollaborationGroupMemberRequest.isAccessible()) CommunityAccess.ThrowAccessException(SObjectType.CollaborationGroupMemberRequest);
			List<CollaborationGroupMemberRequest> cgmrList = [SELECT Id FROM CollaborationGroupMemberRequest WHERE CollaborationGroupId =:cgc.Chatter_Group_ID__c AND RequesterId =:queryInUserId AND Status = 'Pending'];
			if (inmm == 6) {
				//delete cgmrList;
				if (!cgmrList.isEmpty()) {
					CommunityAccess.DeleteWithoutSharing(
						cgmrList,
						'CommunityHelperWithoutSharing.cls [membershipWOSH]'
					);
				}
				resultType = ConnectApi.GroupMembershipType.NotAMember;
			}
			else {
				if (cgmList.size() == 0 && cgmrList.size() == 0) {
					//insert 
					CollaborationGroupMemberRequest cgmr = new CollaborationGroupMemberRequest(CollaborationGroupId = cgc.Chatter_Group_ID__c, RequesterId = inUserId);
					CommunityAccess.InsertWithoutSharing(
						cgmr,
						'CommunityHelperWithoutSharing.cls [membershipWOSH]',
						new List<Schema.DescribeFieldResult> {
							CollaborationGroupMemberRequest.CollaborationGroupId.getDescribe(),
							CollaborationGroupMemberRequest.RequesterId.getDescribe()
						}
					);
				}
				resultType = ConnectApi.GroupMembershipType.NotAMemberPrivateRequested;
			}
		}
		// 7 - Accept Join Private Group Request
		// 8 - Decline Join Private Group Request
		else {
			if (!SObjectType.CollaborationGroupMemberRequest.isAccessible()) CommunityAccess.ThrowAccessException(SObjectType.CollaborationGroupMemberRequest);
			List<CollaborationGroupMemberRequest> cgmrList = [SELECT Id, Status FROM CollaborationGroupMemberRequest WHERE CollaborationGroupId =:cgc.Chatter_Group_ID__c AND RequesterId =:queryInUserId AND Status = 'Pending'];
			if (inmm == 8) {
				if (!cgmrList.isEmpty()) {
					cgmrList[0].Status = 'Declined';
					//update cgmrList;
					CommunityAccess.UpdateWithoutSharing(
						cgmrList,
						'CommunityHelperWithoutSharing.cls [membershipWOSH]',
						new List<Schema.DescribeFieldResult> {
							CollaborationGroupMemberRequest.Status.getDescribe()
						}
					);
				}
				resultType = ConnectApi.GroupMembershipType.NotAMember;
			}
			else {
				if (!cgmrList.isEmpty()) {
					cgmrList[0].Status = 'Accepted';
					//update cgmrList;
					CommunityAccess.UpdateWithoutSharing(
						cgmrList,
						'CommunityHelperWithoutSharing.cls [membershipWOSH]',
						new List<Schema.DescribeFieldResult> {
							CollaborationGroupMemberRequest.Status.getDescribe()
						}
					);
				}
				resultType = ConnectApi.GroupMembershipType.StandardMember;
			}
		}
		return resultType;
	}
}