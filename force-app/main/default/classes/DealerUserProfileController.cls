/**
 * Portal profile photo for the current Experience Cloud user.
 * Stored as a Salesforce File titled Portal_Profile_Photo on Contact (preferred) or User.
 */
public without sharing class DealerUserProfileController {

    private static final String PHOTO_TITLE = 'Portal_Profile_Photo';
    private static final Integer MAX_BYTES = 3 * 1024 * 1024; // 3 MB

    public class ProfilePhotoInfo {
        @AuraEnabled public Id contentDocumentId;
        @AuraEnabled public Id versionId;
        @AuraEnabled public String fileName;
        @AuraEnabled public Boolean hasPhoto;
    }

    @AuraEnabled(cacheable=false)
    public static ProfilePhotoInfo getMyProfilePhoto() {
        Id linkedId = resolvePhotoOwnerId();
        ProfilePhotoInfo info = new ProfilePhotoInfo();
        info.hasPhoto = false;
        if (linkedId == null) {
            return info;
        }

        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId,
                   ContentDocument.Title,
                   ContentDocument.LatestPublishedVersionId,
                   ContentDocument.FileType
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :linkedId
              AND ContentDocument.Title = :PHOTO_TITLE
            ORDER BY ContentDocument.ContentModifiedDate DESC
            LIMIT 1
        ];
        if (links.isEmpty()) {
            return info;
        }

        info.hasPhoto = true;
        info.contentDocumentId = links[0].ContentDocumentId;
        info.versionId = links[0].ContentDocument.LatestPublishedVersionId;
        info.fileName = links[0].ContentDocument.Title;
        return info;
    }

    @AuraEnabled
    public static ProfilePhotoInfo saveMyProfilePhoto(String fileName, String base64Data) {
        if (String.isBlank(base64Data)) {
            throw new AuraHandledException('Please select an image to upload.');
        }
        Id linkedId = resolvePhotoOwnerId();
        if (linkedId == null) {
            throw new AuraHandledException('Unable to resolve profile owner for photo.');
        }

        String cleanName = String.isBlank(fileName) ? 'profile.jpg' : fileName.trim();
        String lower = cleanName.toLowerCase();
        if (!(lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.jpeg')
            || lower.endsWith('.gif') || lower.endsWith('.webp') || lower.endsWith('.bmp'))) {
            // Allow untitled selection from mobile pickers
            if (!lower.contains('.')) {
                cleanName = cleanName + '.jpg';
            } else {
                throw new AuraHandledException('Only image files are allowed (PNG, JPG, GIF, WEBP).');
            }
        }

        Blob body;
        try {
            body = EncodingUtil.base64Decode(base64Data);
        } catch (Exception e) {
            throw new AuraHandledException('Invalid image data.');
        }
        if (body == null || body.size() == 0) {
            throw new AuraHandledException('Image is empty.');
        }
        if (body.size() > MAX_BYTES) {
            throw new AuraHandledException('Image must be under 3 MB.');
        }

        deleteExistingProfilePhotos(linkedId);

        ContentVersion cv = new ContentVersion(
            Title = PHOTO_TITLE,
            PathOnClient = cleanName,
            VersionData = body,
            IsMajorVersion = true,
            FirstPublishLocationId = linkedId
        );
        insert cv;

        // Ensure community can see the file (when FirstPublishLocationId was Contact/User)
        ContentVersion inserted = [
            SELECT ContentDocumentId, ContentDocument.LatestPublishedVersionId
            FROM ContentVersion
            WHERE Id = :cv.Id
            LIMIT 1
        ];

        // Share broadly if a separate link is needed (FirstPublishLocationId already links entity)
        List<ContentDocumentLink> existing = [
            SELECT Id, Visibility, ShareType
            FROM ContentDocumentLink
            WHERE ContentDocumentId = :inserted.ContentDocumentId
              AND LinkedEntityId = :linkedId
            LIMIT 1
        ];
        if (existing.isEmpty()) {
            insert new ContentDocumentLink(
                ContentDocumentId = inserted.ContentDocumentId,
                LinkedEntityId = linkedId,
                ShareType = 'V',
                Visibility = 'AllUsers'
            );
        } else if (existing[0].Visibility != 'AllUsers') {
            existing[0].Visibility = 'AllUsers';
            update existing;
        }

        ProfilePhotoInfo info = new ProfilePhotoInfo();
        info.hasPhoto = true;
        info.contentDocumentId = inserted.ContentDocumentId;
        info.versionId = inserted.ContentDocument.LatestPublishedVersionId;
        info.fileName = cleanName;
        return info;
    }

    private static void deleteExistingProfilePhotos(Id linkedId) {
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :linkedId
              AND ContentDocument.Title = :PHOTO_TITLE
        ];
        if (links.isEmpty()) {
            return;
        }
        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink l : links) {
            docIds.add(l.ContentDocumentId);
        }
        delete [SELECT Id FROM ContentDocument WHERE Id IN :docIds];
    }

    private static Id resolvePhotoOwnerId() {
        User me = [
            SELECT Id, ContactId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        return me.ContactId != null ? me.ContactId : me.Id;
    }
}