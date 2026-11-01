import Foundation

enum L10n {
    nonisolated enum LanguagePreference: String, CaseIterable, Identifiable {
        case system
        case en
        case zh

        var id: String { rawValue }

        var localeIdentifier: String? {
            switch self {
            case .system: return nil
            case .en: return "en"
            case .zh: return "zh-Hans"
            }
        }
    }

    nonisolated static let languagePreferenceUserDefaultsKey = "languagePreference"

    enum Key: String, CaseIterable {
        case expanded, collapsed, selected, notSelected, moveUp, moveDown
        case hostSaveAndConnect, hostConnect, hostDiscardTitle, hostDiscardChanges, hostKeepEditing
        case hostManualImport, hostScanTitle, hostDiscardPairingWarning, hostDiscardChangesWarning
        case sessionsSearchLoaded, sessionsSearchScope, sessionsNoMatches
        case sessionsDeleteConfirmation, sessionsDeleteWarning
        case fileTreeEmpty, fileStatusAdded, fileStatusDeleted, fileStatusModified, fileStatusUntracked
        case chatConnectServer, chatSend, chatAttachImage, chatStopRecording
        case questionGoTo, settingsOpenSystem
        case appChat
        case appClose
        case appDone
        case appLoading
        case appNoContent
        case appError
        case appSearchFiles
        case deepLinkOpening
        case deepLinkInvalid
        case deepLinkSessionUnavailable
        case deepLinkOpenFailed
        case capabilityPermissionTitle
        case capabilityHealthExportTitle
        case capabilityHealthExportDescription
        case capabilityWhatHappens
        case capabilityAgentNote
        case capabilityReason
        case capabilityPermissionFooter
        case capabilityAllowOnce
        case capabilityAllowAlways
        case setupPlanTitle
        case setupPlanSubtitle
        case setupPlanAddressPlaceholder
        case setupPlanEnterToSend
        case setupPlanSend
        case setupPlanIdeasTitle
        case setupPlanIdeaLocal
        case setupPlanIdeaSSH
        case setupPlanIdeaPaste
        case setupPlanIdeaScan
        case capabilitySettingsTitle
        case capabilityAllowedAutomatically
        case capabilityAllowedOtherHost
        case capabilityAskEveryTime
        case capabilityRevoke
        case capabilitySettingsFooter
        case capabilityAlreadyRunning
        case capabilityLaunchFailed
        case capabilityInvalidCallback
        case capabilityContinuationFailed

        case commonOk
        case commonCancel
        case commonRetry

        case carTab
        case navFiles
        case navSettings
        case sidebarHideSessions
        case sidebarShowSessions

        case contentRefreshHelp

        case settingsTitle
        case settingsConnection
        case settingsManageHosts
        case settingsCheck
        case settingsChecking
        case settingsWorkspace
        case settingsProjectShort
        case settingsWorkspaceFooter
        case settingsPreferences
        case settingsInputVoice
        case settingsAdvanced
        case settingsOpenCode
        case settingsUsername
        case settingsPassword
        case settingsConnected
        case settingsDisconnected
        case settingsTestConnection
        case settingsSshSetupGuideTitle
        case settingsSshSetupGuideBody
        case settingsAutoTheme
        case settingsLightTheme
        case settingsDarkTheme
        case settingsAppearance
        case settingsTheme
        case settingsLayout
        case settingsLayoutAutomatic
        case settingsLayoutFocus
        case settingsLayoutFooter
        case settingsVoiceFirst
        case settingsVoiceFirstFooter
        case settingsComposerActionSide
        case settingsComposerLeftHand
        case settingsComposerRightHand
        case settingsShowImageButton
        case settingsSpeechRecognition
        case settingsAbout
        case settingsServerVersion
        case settingsOpenSourceLicences
        case settingsOpenSourceLicencesMissing
        case settingsExperimentalFeatures
        case settingsCarMode
        case settingsAppleOnDevice
        case settingsAppleOnDeviceFooter
        case settingsModelShortlist
        case settingsModelShortlistFooter
        case settingsModelShortlistEmpty
        case settingsModelShortlistAdd
        case settingsModelShortlistSearch
        case settingsModelShortlistEditName
        case settingsModelShortlistShortName
        case settingsModelShortlistAddSelected
        case settingsModelShortlistCatalogEmpty
        case settingsModelShortlistHint
        case settingsModelShortlistSearchClear
        case settingsModelShortlistReorder
        case settingsModelShortlistCatalogHint
        case settingsAIUsageDashboard
        case settingsAIUsageDashboardURL
        case settingsAIUsageDashboardFooter
        case settingsRotateKeyTitle
        case settingsRotateKeyPrompt
        case settingsPublicKeyTitle
        case settingsPublicKeyFooter
        case settingsCopyToClipboard
        case settingsPublicKeyCopied
        case settingsPublicKeyCopyFailed
        case settingsPublicKeyRotate
        case settingsPublicKeyErrorTitle
        case settingsRotate
        case settingsTrustHostKeyTitle
        case settingsTrustHostKeyMessage
        case settingsTrustHostKeyConfirm

        case settingsProject
        case settingsProjectServerDefault
        case settingsProjectCustomPath
        case settingsProjectCustomPathPlaceholder
        case settingsProjectMismatchWarning
        case settingsLanguage
        case settingsLanguageSystem
        case settingsLanguageEnglish
        case settingsLanguageChinese
        case chatCreateDisabledHint

        case hostCurrent
        case hostCurrentFooter
        case hostNoHost
        case hostAddToConnect
        case hostHosts
        case hostDelete
        case hostDuplicate
        case hostEdit
        case hostAdd
        case hostDeviceKey
        case hostCopyDevicePublicKey
        case hostDeviceKeyFooter
        case hostErrorTitle
        case hostNeverConnected
        case hostLastUsed
        case hostOverview
        case hostName
        case hostTransport
        case hostOpenCodeURL
        case hostStatus
        case hostManagedBySSHTunnel
        case hostSavedHost
        case hostSSHTunnel
        case hostSSHGateway
        case hostGatewayHost
        case hostSSHPort
        case hostSSHUsername
        case hostAssignedRemotePort
        case hostConnectionDiagnostics
        case hostUseThisHost
        case hostConfigCopied
        case hostCopyConfigJSON
        case hostNotFound
        case hostImportConfig
        case hostPairSection
        case hostPairScanQR
        case hostPairPasteLink
        case hostPairLinkPlaceholder
        case hostPairRedeeming
        case hostPairPaired
        case hostPairReplaceTitle
        case hostPairReplaceConfirm
        case hostPairReplaceMessage
        case hostPairInvalidLink
        case hostPairCameraDenied
        case hostPairCameraHint
        case hostPairCameraUnavailable
        case hostImportFooter
        case hostConnectionType
        case hostTransportFooter
        case hostSSHGatewayFooter
        case hostDeviceKeySendFooter
        case hostBasicAuth
        case hostSaveHelp
        case hostSave
        case hostEditTitle
        case hostAddTitle
        case hostTitle
        case hostTransportDirect
        case hostUntitled
        case hostDefaultLocalName
        case hostDefaultSSHName
        case hostDuplicateName
        case hostImportErrorDirectRequiresServerURL
        case hostImportErrorSSHTunnelRequiresSSHSettings
        case hostImportErrorInvalidUTF8
        case hostExportErrorEncodeConfigJSON
        case hostConnectionErrorInvalidURL
        case hostConnectionErrorUnsupportedServer
        case hostConnectionErrorBasicAuthRejected
        case hostConnectionErrorHTTPStatus
        case hostConnectionErrorCannotConnect
        case hostConnectionErrorTimedOut
        case hostConnectionErrorDNS
        case hostConnectionErrorNetwork
        case hostConnectionErrorHealthCheckFailed
        case hostConnectionErrorGeneric
        case hostDiagnosticCheckingHealth
        case hostDiagnosticCheckingHealthURL
        case hostDiagnosticConnectingSSHGateway
        case hostDiagnosticHintConfirmGateway
        case hostDiagnosticSSHTunnelFailed
        case hostDiagnosticHintCopyDeviceKeyAgain
        case hostDiagnosticTunnelReadyCheckingHealth
        case hostDiagnosticHintURLFormat
        case hostDiagnosticConnectedToOpenCode
        case hostDiagnosticHealthUnhealthy
        case hostDiagnosticHintCheckServerLogs
        case hostDiagnosticHintVerifyHostConfig
        case hostDiagnosticHintBasicAuth
        case hostDiagnosticLocalListenerFailed
        case hostValidationVPSHostRequired
        case hostValidationSSHUsernameRequired
        case hostValidationSSHPortPositive
        case hostValidationAssignedRemotePortPositive
        case hostSSHTunnelUnavailableVisionOS
        case sshErrorConnectionFailed
        case sshErrorAuthenticationFailed
        case sshErrorKeyNotFound
        case sshErrorInvalidKeyFormat
        case sshErrorTunnelFailed
        case sshErrorHostKeyMismatch
        case sshErrorKeyUnavailable
        case keychainErrorUnhandledStatus

        case connectionPhaseIdle
        case connectionPhaseSSHGateway
        case connectionPhaseSSHAuth
        case connectionPhaseLocalTunnel
        case connectionPhaseHealth
        case connectionPhaseBootstrap
        case connectionPhaseConnected
        case connectionPhaseFailed

        case chatInputPlaceholder
        case chatPaste
        case chatKeyboard
        case chatDismissKeyboard
        case chatSendFailed
        case chatRenameSession
        case chatRenameSessionPlaceholder
        case chatTitleField
        case chatSpeechTitle
        case chatSelectSessionFirst
        case chatSessionBusyMessage
        case chatNoMessages
        case chatGreeting
        case chatTurnCompleted
        case speechApplePermissionDenied
        case speechAppleUnavailable
        case speechAppleOnDeviceUnavailable
        case speechAppleNoSpeech
        case chatSpeechTesting
        case chatSpeechNotPassed
        case chatSpeechTapToSpeak
        case chatSpeechListening
        case chatSpeechTranscriptWillAppear
        case chatSpeechTranscribing
        case chatSpeechTranscribingHint
        case chatSpeechPreservedAudio
        case chatSpeechStopWaiting
        case chatSpeechRetrySegment
        case chatSpeechDiscardAudio
        case chatAbortAgent
        case chatAgentRunning
        case chatAgentWorking
        case chatBackgroundTasksOne
        case chatBackgroundTasksMany
        case chatBackgroundTasksAccessibility
        case chatMicrophoneDenied
        case chatSessionStatusBusy
        case chatSessionStatusRetrying
        case chatSessionStatusIdle
        case chatPullToLoadMore
        case chatLoadingMoreHistory
        case chatLargeMessagePreviewNotice
        case chatLargeMessageTruncatedNotice
        case chatSelectText
        case chatCopyMessage
        case chatEditFromHere
        case chatForkFromHere
        case chatThinkingCard
        case taskNotificationCompleted
        case taskNotificationFailed
        case taskNotificationOpenSession
        case taskNotificationNoOutput
        case carTitle
        case carReady
        case carFinalizing
        case carWorking
        case carNeedsConfirmation
        case carFailed
        case carStartSpeaking
        case carStopAndSend
        case carStopSpeaking
        case carStopResponse
        case carSpeakConfirmation
        case carEmptyPrompt
        case carNewSession
        case carNewSessionPrompt
        case carConfirmUtterance
        case carCancelUtterance
        case carNotConnected
        case carServerDefaultRequired
        case carInvalidResponse
        case carUnsupportedAction
        case carMapsUnavailable
        case carTranscriptionFailed
        case carVoiceMicrophoneDenied
        case carVoiceReady
        case carVoiceListening
        case carVoiceThinking
        case carVoiceSpeaking
        case carVoiceUnavailable
        case carVoiceYou
        case carVoiceOpenCode
        case carVoiceStart
        case carVoiceStop
        case carVoiceEnd
        case carVoicePermissionAsk
        case carVoicePermissionAllowed
        case carVoicePermissionRefused
        case carLiveModeMenuTitle
        case carLiveModeRealtime
        case carLiveModeTurnByTurn
        case carLiveEmptyConversation
        case attachmentImageTitle
        case attachmentFileTitle
        case attachmentRemoveImageAccessibilityLabel
        case attachmentImageReadFailed
        case attachmentImageTooLargeAfterCompression

        case permissionAllowOnce
        case permissionAllowAlways
        case permissionReject
        case permissionAgentRequest
        case questionTitle
        case questionFromAgent
        case questionSingleHint
        case questionMultiHint
        case questionTypeOwnAnswer
        case questionCustomPlaceholder
        case questionDismiss
        case questionSubmit
        case questionBack
        case questionNext
        case questionOf

        case toolReason
        case toolCommandInput
        case toolPath
        case toolOutput
        case toolOpenInFileTree
        case toolOpenFile
        case toolSelectFile
        case toolImageFile
        case toolReadFileAccessibilityLabel
        case toolWriteFileAccessibilityLabel
        case toolReadDirectoryAccessibilityLabel
        case folderEmptyTitle
        case folderEmptyDescription

        case patchFilesChangedOne
        case patchFilesChangedMany

        case changesScopeTurn
        case changesScopeSession
        case changesAdded
        case changesDeleted
        case changesOpenInFiles
        case changesLoadingDiff
        case changesDiffUnavailable
        case changesSectionTitle
        case changesSectionSubtitle
        case changesBadgeAdded
        case changesBadgeModified
        case changesBadgeDeleted
        case changesAccessibilityLabel
        case changesFileAccessibility
        case changesNoDiffForFile

        case projectMemoryTitle
        case projectMemorySectionSubtitle
        case projectMemoryExplains
        case projectMemoryPresent
        case projectMemoryAbsent
        case projectMemoryUnreadable
        case projectMemoryLoading
        case projectMemoryImprove
        case projectMemoryImproveBusy
        case projectMemoryRestore
        case projectMemoryReviewTitle
        case projectMemoryChanged
        case projectMemoryDeleted
        case projectMemoryCreated
        case projectMemoryWorking
        case projectMemoryRestoreNote
        case projectMemoryEmptyContent
        case projectMemoryFileName
        case projectMemoryServerDefault
        case projectMemoryNotText
        case projectMemoryBackToFile
        case projectMemoryKeep
        case projectMemoryActionFailed

        case contextUsageHelp
        case contextUsageClose
        case contextUsageTitle
        case contextUsageSectionSession
        case contextUsageSectionModel
        case contextUsageSectionTokens
        case contextUsageSectionCost
        case contextUsageTitleLabel
        case contextUsageIdLabel
        case contextUsageProviderLabel
        case contextUsageModelLabel
        case contextUsageLimitLabel
        case contextUsageTotalLabel
        case contextUsageInputLabel
        case contextUsageOutputLabel
        case contextUsageReasoningLabel
        case contextUsageCachedReadLabel
        case contextUsageCachedWriteLabel
        case contextUsageNoCostData
        case contextUsageLoadingConfig
        case contextUsageNoUsageData
        case contextUsageConfigNotLoaded
        case contextUsageSectionThroughput
        case contextUsageThroughputAvg
        case contextUsageThroughputTime
        case contextUsageThroughputTokens
        case contextUsageThroughputNoData
        case statusRoundsLabel
        case statusToolsLabel
        case statusTokensLabel
        case statusCacheHitsLabel
        case statusSinceLastPromptLabel
        case quotaTitle
        case quotaDataSource
        case quotaNotLoaded
        case quotaLoading
        case quotaRefreshing
        case quotaRefreshingProviders
        case quotaNoCachedData
        case quotaStale
        case quotaLastFetched
        case quotaGeneratedAt
        case quotaRemainingFormat
        case quotaUsedFormat
        case quotaResetFormat
        case quotaCurrentModelAccessibility

        case sessionTitle
        case sessionsTitle
        case sessionsEmptyTitle
        case sessionsEmptyDescription
        case sessionsClose
        case sessionsNew
        case sessionsUntitled
        case sessionsStatusBusy
        case sessionsIndicatorNeedsYou
        case sessionsIndicatorFailed
        case sessionsIndicatorUnread
        case sessionsStatusRetry
        case sessionsStatusIdle
        case sessionsStatusNeedAttention
        case sessionsActive
        case sessionsArchived
        case sessionsArchive
        case sessionsRestore
        case sessionsLoadMore
        case sessionsActionFailedTitle
        case sessionsDelete

        case fileBinary
        case fileNoContent
        case filePreviewMode
        case fileNativePreview
        case fileWebPreview
        case fileMarkdownSource
        case contentImageDecodeFailed
        case contentNoImageData
        case markdownPreviewLoading
        case markdownWebPreviewLoading
        case markdownWebPreviewLargeDocumentTitle
        case markdownWebPreviewLargeDocumentDescription
        case markdownWebPreviewRenderAnyway
        case markdownWebPreviewOpenNative
        case markdownWebPreviewOpenSource
        case markdownWebPreviewFailedTitle
        case markdownWebPreviewAssetsMissing
        case markdownWebPreviewPayloadEncodeFailed
        case markdownWebPreviewRenderCallFailed
        case markdownWebPreviewWebViewLoadFailed
        case markdownWebPreviewWebViewProvisionalLoadFailed
        case markdownWebPreviewUnknownRenderError

        case errorConnectionFailed
        case errorServerError
        case errorInvalidResponse
        case errorUnauthorized
        case errorSessionNotFound
        case errorFileNotFound
        case errorOperationFailed
        case errorUnknown
        case errorInvalidBaseURL
        case errorServerAddressEmpty
        case errorWanRequiresHttps
        case errorUsingLanHttp
        case helpLanHttp
        case helpWanHttp
        case helpTailscaleHttp

        case activityRetrying
        case activityThinking
        case activityDelegating
        case activityPlanning
        case activityGatheringContext
        case activitySearchingCodebase
        case activitySearchingWeb
        case activityMakingEdits
        case activityRunningCommands
        case activityGatheringThoughts
        case configureTitle
        case configureModel
        case configureAgent
        case configureNoAgents
        case configureModelSearchPlaceholder
        case configureModelNoMatches
        case configureModelEmptyShortlist
        case configureModelEditShortlist

        case todoPanelTitle
        case todoPanelCompleted
        case todoPanelEmpty
        case todoUpdatedBadge
    }

    nonisolated private static let en: [String: String] = [
        Key.expanded.rawValue: "Expanded",
        Key.collapsed.rawValue: "Collapsed",
        Key.selected.rawValue: "Selected",
        Key.notSelected.rawValue: "Not selected",
        Key.moveUp.rawValue: "Move up",
        Key.moveDown.rawValue: "Move down",
        Key.hostSaveAndConnect.rawValue: "Save and Connect",
        Key.hostConnect.rawValue: "Connect to This Host",
        Key.hostDiscardTitle.rawValue: "Discard unsaved host changes?",
        Key.hostDiscardChanges.rawValue: "Discard Changes",
        Key.hostKeepEditing.rawValue: "Keep Editing",
        Key.hostDiscardPairingWarning.rawValue: "Discarding also loses the paired credentials. A redeemed pairing code cannot be used again; generate a new code on the server to pair later.",
        Key.hostDiscardChangesWarning.rawValue: "The host details you typed will not be saved.",
        Key.hostManualImport.rawValue: "Import JSON configuration",
        Key.hostScanTitle.rawValue: "Scan pairing code",
        Key.sessionsSearchLoaded.rawValue: "Search loaded sessions",
        Key.sessionsSearchScope.rawValue: "Searches titles in loaded sessions for this host and project. Load more to include older sessions.",
        Key.sessionsNoMatches.rawValue: "No matching loaded sessions",
        Key.sessionsDeleteConfirmation.rawValue: "Delete session?",
        Key.sessionsDeleteWarning.rawValue: "“%@” will be permanently deleted from the server. This cannot be undone. Archive instead if you may need it later.",
        Key.fileTreeEmpty.rawValue: "This workspace is empty",
        Key.fileStatusAdded.rawValue: "Added",
        Key.fileStatusDeleted.rawValue: "Deleted",
        Key.fileStatusModified.rawValue: "Modified",
        Key.fileStatusUntracked.rawValue: "Untracked",
        Key.chatConnectServer.rawValue: "Connect a Server",
        Key.chatSend.rawValue: "Send message",
        Key.chatAttachImage.rawValue: "Attach image",
        Key.chatStopRecording.rawValue: "Stop recording",
        Key.questionGoTo.rawValue: "Go to question %d",
        Key.settingsOpenSystem.rawValue: "Open System Settings",
        Key.appChat.rawValue: "Chat",
        Key.appClose.rawValue: "Close",
        Key.appDone.rawValue: "Done",
        Key.appLoading.rawValue: "Loading...",
        Key.appNoContent.rawValue: "No content",
        Key.appError.rawValue: "Error",
        Key.appSearchFiles.rawValue: "Search files",
        Key.deepLinkOpening.rawValue: "Opening session...",
        Key.deepLinkInvalid.rawValue: "This OpenCode session link is invalid.",
        Key.deepLinkSessionUnavailable.rawValue: "This session is not available on the current host. It may belong to another host or exist only in offline history.",
        Key.deepLinkOpenFailed.rawValue: "OpenCode could not open this session. Check the current host connection and try again.",
        Key.capabilityPermissionTitle.rawValue: "Client Capability",
        Key.capabilityHealthExportTitle.rawValue: "Sync Health Quantification data",
        Key.capabilityHealthExportDescription.rawValue: "Export the latest HealthKit data to the configured Health Quantification server.",
        Key.capabilityWhatHappens.rawValue: "What happens",
        Key.capabilityAgentNote.rawValue: "Note from the requesting agent",
        Key.capabilityReason.rawValue: "Reason",
        Key.capabilityPermissionFooter.rawValue: "OpenCode constructs a one-time callback. Health details are not returned through the link.",
        Key.capabilityAllowOnce.rawValue: "Allow Once",
        Key.capabilityAllowAlways.rawValue: "Always Allow",
        Key.setupPlanTitle.rawValue: "Let's connect your server",
        Key.setupPlanSubtitle.rawValue: "OpenCodex talks straight to your OpenCode server. Tell us where it is, or pick one of the starting points below.",
        Key.setupPlanAddressPlaceholder.rawValue: "Server address, e.g. 192.168.1.10:4096",
        Key.setupPlanEnterToSend.rawValue: "Enter to send",
        Key.setupPlanSend.rawValue: "Send",
        Key.setupPlanIdeasTitle.rawValue: "Ideas for you",
        Key.setupPlanIdeaLocal.rawValue: "A local server",
        Key.setupPlanIdeaSSH.rawValue: "An SSH tunnel",
        Key.setupPlanIdeaPaste.rawValue: "Paste a pairing code",
        Key.setupPlanIdeaScan.rawValue: "Scan a pairing code",
        Key.capabilitySettingsTitle.rawValue: "Client Capabilities",
        Key.capabilityAllowedAutomatically.rawValue: "Allowed automatically",
        Key.capabilityAllowedOtherHost.rawValue: "Granted to a different host",
        Key.capabilityAskEveryTime.rawValue: "Ask every time",
        Key.capabilityRevoke.rawValue: "Revoke Automatic Access",
        Key.capabilitySettingsFooter.rawValue: "Automatic access only applies to exporting Health data. It does not authorize analysis or other side effects.",
        Key.capabilityAlreadyRunning.rawValue: "A Health export is already in progress.",
        Key.capabilityLaunchFailed.rawValue: "Health Quantification is not installed or could not be opened.",
        Key.capabilityInvalidCallback.rawValue: "OpenCode rejected an invalid or expired Health export callback.",
        Key.capabilityContinuationFailed.rawValue: "The Health export finished, but OpenCode could not continue the original session.",
        Key.commonOk.rawValue: "OK",
        Key.commonCancel.rawValue: "Cancel",
        Key.commonRetry.rawValue: "Retry",
        Key.carTab.rawValue: "Ambient Mode",
        Key.navFiles.rawValue: "Files",
        Key.navSettings.rawValue: "Settings",
        Key.sidebarHideSessions.rawValue: "Hide sessions",
        Key.sidebarShowSessions.rawValue: "Show sessions",
        Key.contentRefreshHelp.rawValue: "Refresh preview",

        Key.settingsTitle.rawValue: "Settings",
        Key.settingsConnection.rawValue: "Connection",
        Key.settingsManageHosts.rawValue: "Manage hosts",
        Key.settingsCheck.rawValue: "Check",
        Key.settingsChecking.rawValue: "Checking…",
        Key.settingsWorkspace.rawValue: "Workspace",
        Key.settingsProjectShort.rawValue: "Project",
        Key.settingsWorkspaceFooter.rawValue: "Choose the project and models available in chat.",
        Key.settingsPreferences.rawValue: "Preferences",
        Key.settingsInputVoice.rawValue: "Input & Voice",
        Key.settingsAdvanced.rawValue: "Advanced",
        Key.settingsOpenCode.rawValue: "OpenCode",
        Key.settingsUsername.rawValue: "Username",
        Key.settingsPassword.rawValue: "Password",
        Key.settingsConnected.rawValue: "Connected",
        Key.settingsDisconnected.rawValue: "Disconnected",
        Key.settingsTestConnection.rawValue: "Test Connection",
        Key.settingsPublicKeyCopied.rawValue: "Public Key Copied",
        Key.settingsSshSetupGuideTitle.rawValue: "SSH Gateway Setup",
        Key.settingsSshSetupGuideBody.rawValue: "1. Tap Copy Public Key and send it to the server admin.\n\n2. The admin adds this device key to your user and gives you Host, SSH Port, Username, and Assigned Remote Port. For opencode-private-host, Username is usually opencode, SSH Port is usually 8006, and the first user's Remote Port is usually 19001.\n\n3. Fill those values here, enable SSH Tunnel, then tap Set Server Address to 127.0.0.1:4096.\n\n4. Tap Test Connection. The app will connect to local 127.0.0.1:4096; the SSH tunnel forwards it to your private OpenCode container.\n\n5. If provider auth is not configured yet, ask the admin to complete the first provider login in the OpenCode Web UI.",
        Key.settingsAutoTheme.rawValue: "Auto",
        Key.settingsLightTheme.rawValue: "Light",
        Key.settingsDarkTheme.rawValue: "Dark",
        Key.settingsAppearance.rawValue: "Appearance",
        Key.settingsTheme.rawValue: "Theme",
        Key.settingsLayout.rawValue: "Layout Mode",
        Key.settingsLayoutAutomatic.rawValue: "Auto",
        Key.settingsLayoutFocus.rawValue: "Focus",
        Key.settingsLayoutFooter.rawValue: "Focus shows one content area on large screens and keeps the input area when opening files in chat.",
        Key.settingsVoiceFirst.rawValue: "Voice-First",
        Key.settingsComposerActionSide.rawValue: "Composer controls",
        Key.settingsComposerLeftHand.rawValue: "Left-hand side mode",
        Key.settingsComposerRightHand.rawValue: "Right-hand side mode",
        Key.settingsShowImageButton.rawValue: "Show image button",
        Key.settingsVoiceFirstFooter.rawValue: "When on, tapping a draft won't show the keyboard. Use Paste, or tap the keyboard button to edit.",
        Key.settingsSpeechRecognition.rawValue: "Speech Recognition",
        Key.settingsAbout.rawValue: "About",
        Key.settingsServerVersion.rawValue: "Server Version",
        Key.settingsOpenSourceLicences.rawValue: "Open source licences",
        Key.settingsOpenSourceLicencesMissing.rawValue: "The licence notices are missing from this build.",
        Key.settingsExperimentalFeatures.rawValue: "Experimental Features",
        Key.settingsCarMode.rawValue: "Ambient Mode",
        Key.settingsAppleOnDevice.rawValue: "Apple On-Device",
        Key.settingsAppleOnDeviceFooter.rawValue: "Transcription runs entirely on this device with Apple's speech recognizer. Nothing is uploaded and no account is needed.",
        Key.settingsModelShortlist.rawValue: "Models",
        Key.settingsModelShortlistFooter.rawValue: "The chat picker only shows this shortlist. Add models from the connected server.",
        Key.settingsModelShortlistEmpty.rawValue: "No models yet. Tap + to search and add.",
        Key.settingsModelShortlistAdd.rawValue: "Add Models",
        Key.settingsModelShortlistSearch.rawValue: "Search catalog",
        Key.settingsModelShortlistEditName.rawValue: "Short Name",
        Key.settingsModelShortlistShortName.rawValue: "Toolbar label",
        Key.settingsModelShortlistAddSelected.rawValue: "Add",
        Key.settingsModelShortlistCatalogEmpty.rawValue: "Connect to a server to load the model catalog.",
        Key.settingsModelShortlistHint.rawValue: "The chat picker shows this list, in this order. Drag to rearrange, swipe left to delete. Tap + to add models.",
        Key.settingsModelShortlistSearchClear.rawValue: "Clear search",
        Key.settingsModelShortlistReorder.rawValue: "Reorder",
        Key.settingsModelShortlistCatalogHint.rawValue: "Search and tap to select. Add puts the checked models on your list. To remove one, go back and swipe it away.",
        Key.settingsAIUsageDashboard.rawValue: "AI Usage Dashboard",
        Key.settingsAIUsageDashboardURL.rawValue: "Dashboard URL (optional)",
        Key.settingsAIUsageDashboardFooter.rawValue: "Leave blank for no quota UI. Enter the dashboard base URL or the full /api/v1/quotas endpoint.",
        Key.settingsRotateKeyTitle.rawValue: "Rotate SSH Key?",
        Key.settingsRotateKeyPrompt.rawValue: "This will generate a new key pair for this device. Update the public key on your SSH server before using SSH tunnel hosts again.",
        Key.settingsPublicKeyTitle.rawValue: "Your Public Key",
        Key.settingsPublicKeyFooter.rawValue: "Send this public key to the server admin. Do not share your private key.",
        Key.settingsCopyToClipboard.rawValue: "Copy to Clipboard",
        Key.settingsPublicKeyCopyFailed.rawValue: "Unable to load SSH public key.",
        Key.settingsPublicKeyRotate.rawValue: "Rotate Key",
        Key.settingsPublicKeyErrorTitle.rawValue: "Public Key Error",
        Key.settingsRotate.rawValue: "Rotate",
        Key.settingsTrustHostKeyTitle.rawValue: "Trust New SSH Host Key?",
        Key.settingsTrustHostKeyMessage.rawValue: "%@:%d presented a different host key.\n\nPrevious: %@\nNew: %@\n\nTrust it only if you expected the server to be rebuilt or reinstalled.",
        Key.settingsTrustHostKeyConfirm.rawValue: "Trust and Reconnect",
        Key.settingsProject.rawValue: "Project (Workspace)",
        Key.settingsProjectServerDefault.rawValue: "Server default",
        Key.settingsProjectCustomPath.rawValue: "Custom path",
        Key.settingsProjectCustomPathPlaceholder.rawValue: "/path/to/project",
        Key.settingsProjectMismatchWarning.rawValue: "Server default project is {server}. New sessions will be created there, not in {effective}. To create sessions in {effective}, start OpenCode from the command line with that project as working directory.",
        Key.settingsLanguage.rawValue: "Language",
        Key.settingsLanguageSystem.rawValue: "System",
        Key.settingsLanguageEnglish.rawValue: "English",
        Key.settingsLanguageChinese.rawValue: "Chinese",
        Key.chatCreateDisabledHint.rawValue: "New sessions can only be created when using Server default project. To create sessions in another project, start OpenCode from the command line with a different working directory, then select Server default here.",

        Key.hostCurrent.rawValue: "Current Host",
        Key.hostCurrentFooter.rawValue: "A host is one OpenCode environment. It can be reached directly over LAN, Tailscale, VPN, HTTPS, or through an SSH tunnel.",
        Key.hostNoHost.rawValue: "No Host",
        Key.hostAddToConnect.rawValue: "Add a host to connect",
        Key.hostHosts.rawValue: "Hosts",
        Key.hostDelete.rawValue: "Delete",
        Key.hostDuplicate.rawValue: "Duplicate",
        Key.hostEdit.rawValue: "Edit",
        Key.hostAdd.rawValue: "Add Host",
        Key.hostDeviceKey.rawValue: "Device Key",
        Key.hostCopyDevicePublicKey.rawValue: "Copy This Device Public Key",
        Key.hostDeviceKeyFooter.rawValue: "Use this same device key for SSH tunnel hosts. Direct hosts do not need it.",
        Key.hostErrorTitle.rawValue: "Host Error",
        Key.hostNeverConnected.rawValue: "Never connected",
        Key.hostLastUsed.rawValue: "Last used %@",
        Key.hostOverview.rawValue: "Overview",
        Key.hostName.rawValue: "Name",
        Key.hostTransport.rawValue: "Transport",
        Key.hostOpenCodeURL.rawValue: "OpenCode URL",
        Key.hostStatus.rawValue: "Status",
        Key.hostManagedBySSHTunnel.rawValue: "Managed by SSH tunnel",
        Key.hostSavedHost.rawValue: "Saved Host",
        Key.hostSSHTunnel.rawValue: "SSH Tunnel",
        Key.hostSSHGateway.rawValue: "SSH Gateway",
        Key.hostGatewayHost.rawValue: "Gateway Host",
        Key.hostSSHPort.rawValue: "SSH Port",
        Key.hostSSHUsername.rawValue: "SSH Username",
        Key.hostAssignedRemotePort.rawValue: "Assigned Remote Port",
        Key.hostConnectionDiagnostics.rawValue: "Connection Diagnostics",
        Key.hostUseThisHost.rawValue: "Use This Host",
        Key.hostConfigCopied.rawValue: "Host Config Copied",
        Key.hostCopyConfigJSON.rawValue: "Copy Host Config JSON",
        Key.hostNotFound.rawValue: "Host not found",
        Key.hostImportConfig.rawValue: "Import Host Config",
        Key.hostImportFooter.rawValue: "Paste a setup JSON from your server admin. Import fills this form; Save commits the configuration.",
        Key.hostConnectionType.rawValue: "Connection Type",
        Key.hostTransportFooter.rawValue: "Direct is for LAN, VPN, Tailscale, or HTTPS. SSH Tunnel is for an OpenCode server behind an SSH gateway.",
        Key.hostSSHGatewayFooter.rawValue: "These values come from your OpenCode host admin. The app connects locally through the tunnel after this is saved.",
        Key.hostDeviceKeySendFooter.rawValue: "Send this public key to the server admin before testing. Never share the private key.",
        Key.hostBasicAuth.rawValue: "Basic Auth",
        Key.hostSaveHelp.rawValue: "Save stores this configuration and selects the host. Save and Connect also checks the connection. Cancel discards only changes that have not been saved.",
        Key.hostPairSection.rawValue: "Pair with OpenCode",
        Key.hostPairScanQR.rawValue: "Scan QR code",
        Key.hostPairPasteLink.rawValue: "Or paste a pairing link",
        Key.hostPairLinkPlaceholder.rawValue: "http://host:port/auth/connect/…",
        Key.hostPairRedeeming.rawValue: "Pairing…",
        Key.hostPairPaired.rawValue: "Paired with %@",
        Key.hostPairReplaceTitle.rawValue: "Replace the server address?",
        Key.hostPairReplaceConfirm.rawValue: "Replace",
        Key.hostPairReplaceMessage.rawValue: "The pairing code points at %@. This host currently points at %@. Replace the address and use the new credentials?",
        Key.hostPairInvalidLink.rawValue: "That is not an OpenCode pairing link.",
        Key.hostPairCameraDenied.rawValue: "Camera access is off. Enable it in Settings, or paste the pairing link instead.",
        Key.hostPairCameraHint.rawValue: "Run `opencode pair` on the server and point the camera at the QR code.",
        Key.hostPairCameraUnavailable.rawValue: "This device has no camera. Paste the pairing link instead.",
        Key.hostSave.rawValue: "Save",
        Key.hostEditTitle.rawValue: "Edit Host",
        Key.hostAddTitle.rawValue: "Add Host",
        Key.hostTitle.rawValue: "Host",
        Key.hostTransportDirect.rawValue: "Direct",
        Key.hostUntitled.rawValue: "Untitled Host",
        Key.hostDefaultLocalName.rawValue: "Local OpenCode",
        Key.hostDefaultSSHName.rawValue: "SSH OpenCode",
        Key.hostDuplicateName.rawValue: "%@ Copy",
        Key.hostImportErrorDirectRequiresServerURL.rawValue: "Direct host config requires serverURL.",
        Key.hostImportErrorSSHTunnelRequiresSSHSettings.rawValue: "SSH Tunnel host config requires ssh settings.",
        Key.hostImportErrorInvalidUTF8.rawValue: "Host config is not valid UTF-8.",
        Key.hostExportErrorEncodeConfigJSON.rawValue: "Could not encode Host Config JSON.",
        Key.hostConnectionErrorInvalidURL.rawValue: "Invalid OpenCode URL. Check the host address and port.",
        Key.hostConnectionErrorUnsupportedServer.rawValue: "This address is not an OpenCode server. It does not answer the OpenCode API.",
        // HIG Feedback: the diagnostic states what happened; the paired
        // recovery hint carries the action, so the message never repeats it.
        Key.hostConnectionErrorBasicAuthRejected.rawValue: "OpenCode rejected Basic Auth.",
        Key.hostConnectionErrorHTTPStatus.rawValue: "OpenCode returned HTTP %d. Check the server logs or provider setup.",
        Key.hostConnectionErrorCannotConnect.rawValue: "Could not connect to OpenCode. Check network reachability and that the server is running.",
        Key.hostConnectionErrorTimedOut.rawValue: "Connection timed out. Check the host, port, VPN/Tailscale, and firewall.",
        Key.hostConnectionErrorDNS.rawValue: "Host name could not be resolved. Check the gateway or server host spelling.",
        Key.hostConnectionErrorNetwork.rawValue: "Network error: %@",
        Key.hostConnectionErrorHealthCheckFailed.rawValue: "OpenCode health check failed. Check that the server is running and reachable.",
        Key.hostConnectionErrorGeneric.rawValue: "Connection failed. Check the host configuration and try again.",
        Key.hostDiagnosticCheckingHealth.rawValue: "Checking OpenCode health...",
        Key.hostDiagnosticCheckingHealthURL.rawValue: "Checking %@/global/health...",
        Key.hostDiagnosticConnectingSSHGateway.rawValue: "Connecting to SSH gateway...",
        Key.hostDiagnosticHintConfirmGateway.rawValue: "Confirm the gateway host, SSH port, device public key, and network reachability.",
        Key.hostDiagnosticSSHTunnelFailed.rawValue: "SSH tunnel failed: %@",
        Key.hostDiagnosticHintCopyDeviceKeyAgain.rawValue: "Copy this device public key again if the server has not authorized it.",
        Key.hostDiagnosticTunnelReadyCheckingHealth.rawValue: "SSH tunnel is ready; checking OpenCode health...",
        Key.hostDiagnosticHintURLFormat.rawValue: "Use host:port, http://host:port, or https://host:port.",
        Key.hostDiagnosticConnectedToOpenCode.rawValue: "Connected to OpenCode%@.",
        Key.hostDiagnosticHealthUnhealthy.rawValue: "OpenCode health check returned unhealthy.",
        Key.hostDiagnosticHintCheckServerLogs.rawValue: "Check the OpenCode server process and logs.",
        Key.hostDiagnosticHintVerifyHostConfig.rawValue: "For SSH tunnel hosts, first verify the gateway values and device key. For direct hosts, verify the URL from this device.",
        Key.hostDiagnosticHintBasicAuth.rawValue: "Check the username and password for this host.",
        Key.hostDiagnosticLocalListenerFailed.rawValue: "Local listener failed: %@",
        Key.hostValidationVPSHostRequired.rawValue: "VPS Host is required",
        Key.hostValidationSSHUsernameRequired.rawValue: "SSH Username is required",
        Key.hostValidationSSHPortPositive.rawValue: "SSH Port must be > 0",
        Key.hostValidationAssignedRemotePortPositive.rawValue: "Assigned Remote Port must be > 0",
        Key.hostSSHTunnelUnavailableVisionOS.rawValue: "SSH tunnels are not available in the visionOS build yet. Connect directly to an OpenCode server instead.",
        Key.sshErrorConnectionFailed.rawValue: "Connection failed: %@",
        Key.sshErrorAuthenticationFailed.rawValue: "Authentication failed. Please check your public key is added to the server.",
        Key.sshErrorKeyNotFound.rawValue: "SSH key not found. Please generate a key pair first.",
        Key.sshErrorInvalidKeyFormat.rawValue: "Invalid SSH key format.",
        Key.sshErrorTunnelFailed.rawValue: "Tunnel failed: %@",
        Key.sshErrorHostKeyMismatch.rawValue: "Host key mismatch. Expected %@, got %@. This may be a MITM attack or a reinstalled server. Reset trusted host and verify fingerprint before reconnecting.",
        Key.sshErrorKeyUnavailable.rawValue: "SSH key is unavailable right now. Unlock the device and try again.",
        Key.keychainErrorUnhandledStatus.rawValue: "Keychain operation failed (OSStatus %d).",

        Key.connectionPhaseIdle.rawValue: "Idle",
        Key.connectionPhaseSSHGateway.rawValue: "Connecting to SSH gateway",
        Key.connectionPhaseSSHAuth.rawValue: "Authenticating with device key",
        Key.connectionPhaseLocalTunnel.rawValue: "Starting local tunnel",
        Key.connectionPhaseHealth.rawValue: "Checking OpenCode health",
        Key.connectionPhaseBootstrap.rawValue: "Loading projects and sessions",
        Key.connectionPhaseConnected.rawValue: "Connected",
        Key.connectionPhaseFailed.rawValue: "Connection failed",

        Key.chatInputPlaceholder.rawValue: "Ask anything...",
        Key.chatPaste.rawValue: "Paste",
        Key.chatKeyboard.rawValue: "Keyboard",
        Key.chatDismissKeyboard.rawValue: "Hide Keyboard",
        Key.chatSendFailed.rawValue: "Send failed",
        Key.chatRenameSession.rawValue: "Rename Session",
        Key.chatRenameSessionPlaceholder.rawValue: "Input new title",
        Key.chatTitleField.rawValue: "Title",
        Key.chatSpeechTitle.rawValue: "Speech Recognition",
        Key.chatSelectSessionFirst.rawValue: "Please pick a session first",
        Key.chatSessionBusyMessage.rawValue: "Session is running, messages are not visible yet, refreshing...",
        Key.chatNoMessages.rawValue: "No messages yet",
        Key.chatGreeting.rawValue: "How can I help you?",
        Key.chatTurnCompleted.rawValue: "Completed",
        Key.speechApplePermissionDenied.rawValue: "Speech recognition permission denied. Enable it in Settings → Privacy & Security → Speech Recognition.",
        Key.speechAppleUnavailable.rawValue: "On-device speech recognition is not available on this device.",
        Key.speechAppleOnDeviceUnavailable.rawValue: "On-device speech recognition is not available for your language yet. Pick a cloud strategy in Settings → Speech Recognition.",
        Key.speechAppleNoSpeech.rawValue: "No speech detected in the recording.",
        Key.chatSpeechTesting.rawValue: "AI Builder connection is being tested, please wait.",
        Key.chatSpeechNotPassed.rawValue: "AI Builder connection test failed. Go to Settings → Speech Recognition, tap Test Connection, and confirm it's OK before recording.",
        Key.chatSpeechTapToSpeak.rawValue: "Tap to speak",
        Key.chatSpeechListening.rawValue: "Listening...",
        Key.chatSpeechTranscriptWillAppear.rawValue: "Transcript will appear here...",
        Key.chatSpeechTranscribing.rawValue: "Transcribing...",
        Key.chatSpeechTranscribingHint.rawValue: "Finishing transcript...",
        Key.chatSpeechPreservedAudio.rawValue: "Audio saved. Retry this segment.",
        Key.chatSpeechStopWaiting.rawValue: "Stop transcription wait",
        Key.chatSpeechRetrySegment.rawValue: "Retry this segment",
        Key.chatSpeechDiscardAudio.rawValue: "Discard audio",
        Key.chatAbortAgent.rawValue: "Interrupt agent",
        Key.chatAgentRunning.rawValue: "Agent running",
        Key.chatAgentWorking.rawValue: "Agent working",
        Key.chatBackgroundTasksOne.rawValue: "Subagent running",
        Key.chatBackgroundTasksMany.rawValue: "%d subagents running",
        Key.chatBackgroundTasksAccessibility.rawValue: "Subagent running in background. Tap to open subagent session.",
        Key.chatMicrophoneDenied.rawValue: "Microphone permission denied",
        Key.chatSessionStatusBusy.rawValue: "Running",
        Key.chatSessionStatusRetrying.rawValue: "Retrying",
        Key.chatSessionStatusIdle.rawValue: "Idle",
        Key.chatPullToLoadMore.rawValue: "Pull down to load more history",
        Key.chatLoadingMoreHistory.rawValue: "Loading more history...",
        Key.chatLargeMessagePreviewNotice.rawValue: "Long message: %@ characters. Markdown rendering is skipped to keep the app responsive.",
        Key.chatLargeMessageTruncatedNotice.rawValue: "Long message: showing the first %@ of %@ characters. Markdown rendering is skipped to keep the app responsive.",
        Key.chatSelectText.rawValue: "Select Text",
        Key.chatCopyMessage.rawValue: "Copy Message",
        Key.chatEditFromHere.rawValue: "Edit from here",
        Key.chatForkFromHere.rawValue: "Fork from here",
        Key.chatThinkingCard.rawValue: "Thinking",
        Key.taskNotificationCompleted.rawValue: "Completed",
        Key.taskNotificationFailed.rawValue: "Failed",
        Key.taskNotificationOpenSession.rawValue: "Open subagent session",
        Key.taskNotificationNoOutput.rawValue: "No output",
        Key.carTitle.rawValue: "Ambient Mode",
        Key.carReady.rawValue: "Ready",
        Key.carFinalizing.rawValue: "Finishing transcript",
        Key.carWorking.rawValue: "OpenCode is working",
        Key.carNeedsConfirmation.rawValue: "Confirmation needed",
        Key.carFailed.rawValue: "Needs attention",
        Key.carStartSpeaking.rawValue: "Start speaking",
        Key.carStopAndSend.rawValue: "Stop and send",
        Key.carStopSpeaking.rawValue: "Stop speaking",
        Key.carStopResponse.rawValue: "Stop response",
        Key.carSpeakConfirmation.rawValue: "Say confirm or cancel",
        Key.carEmptyPrompt.rawValue: "Ask about home, messages, traffic, or where to go.",
        Key.carNewSession.rawValue: "New Ambient Mode Session",
        Key.carNewSessionPrompt.rawValue: "Start a new Ambient Mode session and leave the current context behind?",
        Key.carConfirmUtterance.rawValue: "Confirm.",
        Key.carCancelUtterance.rawValue: "Cancel.",
        Key.carNotConnected.rawValue: "Connect to OpenCode before using Ambient Mode.",
        Key.carServerDefaultRequired.rawValue: "Ambient Mode can create sessions only in the Server default workspace.",
        Key.carInvalidResponse.rawValue: "OpenCode returned an invalid Ambient Mode response.",
        Key.carUnsupportedAction.rawValue: "OpenCode requested an unsupported client action.",
        Key.carMapsUnavailable.rawValue: "Apple Maps could not open this route.",
        Key.carTranscriptionFailed.rawValue: "The recording could not be transcribed.",
        Key.carVoiceMicrophoneDenied.rawValue: "Ambient Mode needs the microphone.",
        Key.carVoiceReady.rawValue: "Ready",
        Key.carVoiceListening.rawValue: "Listening",
        Key.carVoiceThinking.rawValue: "Thinking",
        Key.carVoiceSpeaking.rawValue: "Speaking",
        Key.carVoiceUnavailable.rawValue: "Voice is unavailable: %@",
        Key.carVoiceYou.rawValue: "You",
        Key.carVoiceOpenCode.rawValue: "OpenCode",
        Key.carVoiceStart.rawValue: "Start listening",
        Key.carVoiceStop.rawValue: "Stop listening",
        Key.carVoiceEnd.rawValue: "End the conversation",
        Key.carVoicePermissionAsk.rawValue: "The agent needs permission to run %@. Say yes to allow it once, or no to refuse.",
        Key.carVoicePermissionAllowed.rawValue: "Allowed.",
        Key.carVoicePermissionRefused.rawValue: "Refused.",
        Key.carLiveModeMenuTitle.rawValue: "Voice Mode",
        Key.carLiveModeRealtime.rawValue: "Live Voice",
        Key.carLiveModeTurnByTurn.rawValue: "Sentence by sentence",
        Key.carLiveEmptyConversation.rawValue: "No conversation yet",
        Key.attachmentImageTitle.rawValue: "Image",
        Key.attachmentFileTitle.rawValue: "Attachment",
        Key.attachmentRemoveImageAccessibilityLabel.rawValue: "Remove image",
        Key.attachmentImageReadFailed.rawValue: "Could not read the selected image.",
        Key.attachmentImageTooLargeAfterCompression.rawValue: "Image is too large after compression (%@ MB). Please choose a smaller image.",

        Key.changesScopeTurn.rawValue: "this turn",
        Key.changesScopeSession.rawValue: "this session",
        Key.changesAdded.rawValue: "+%d",
        Key.changesDeleted.rawValue: "−%d",
        Key.changesOpenInFiles.rawValue: "Open in Files",
        Key.changesLoadingDiff.rawValue: "Reading the diff…",
        Key.changesDiffUnavailable.rawValue: "Couldn't load the diff",
        Key.changesSectionTitle.rawValue: "Changes",
        Key.changesSectionSubtitle.rawValue: "in this session",
        Key.changesBadgeAdded.rawValue: "new",
        Key.changesBadgeModified.rawValue: "mod",
        Key.changesBadgeDeleted.rawValue: "del",
        Key.changesAccessibilityLabel.rawValue: "%d files changed, %d lines added, %d lines removed",
        Key.changesFileAccessibility.rawValue: "%@, %d lines added, %d lines removed",
        Key.changesNoDiffForFile.rawValue: "No diff for this file",
        Key.projectMemoryTitle.rawValue: "Project Memory",
        Key.projectMemorySectionSubtitle.rawValue: "Injected into every agent turn",
        Key.projectMemoryExplains.rawValue: "This file is injected into every agent turn. It is how the agent remembers your project between sessions.",
        Key.projectMemoryPresent.rawValue: "%@ · %d lines",
        Key.projectMemoryAbsent.rawValue: "No project memory yet",
        Key.projectMemoryUnreadable.rawValue: "Could not read %@",
        Key.projectMemoryLoading.rawValue: "Reading project memory…",
        Key.projectMemoryImprove.rawValue: "Improve with the agent",
        Key.projectMemoryImproveBusy.rawValue: "The agent is busy",
        Key.projectMemoryRestore.rawValue: "Restore previous version",
        Key.projectMemoryReviewTitle.rawValue: "Review the change",
        Key.projectMemoryChanged.rawValue: "The agent changed this file.",
        Key.projectMemoryDeleted.rawValue: "The agent deleted this file.",
        Key.projectMemoryCreated.rawValue: "The agent created this file.",
        Key.projectMemoryWorking.rawValue: "The agent is updating project memory…",
        Key.projectMemoryRestoreNote.rawValue: "The agent restores the file by rewriting it, so the result may differ slightly from the version you accepted.",
        Key.projectMemoryEmptyContent.rawValue: "This file is empty.",
        Key.projectMemoryFileName.rawValue: "AGENTS.md",
        Key.projectMemoryServerDefault.rawValue: "the server's default directory",
        Key.projectMemoryNotText.rawValue: "This file is not text.",
        Key.projectMemoryBackToFile.rawValue: "Back to the file",
        Key.projectMemoryKeep.rawValue: "Keep this version",
        Key.projectMemoryActionFailed.rawValue: "The agent could not be asked. Check the connection and try again.",

        Key.permissionAllowOnce.rawValue: "Allow Once",
        Key.permissionAllowAlways.rawValue: "Allow Always",
        Key.permissionReject.rawValue: "Reject",
        Key.permissionAgentRequest.rawValue: "Requested by the agent",
        Key.questionTitle.rawValue: "Question",
        Key.questionFromAgent.rawValue: "Asked by the agent",
        Key.questionSingleHint.rawValue: "Select one option",
        Key.questionMultiHint.rawValue: "Select one or more options",
        Key.questionTypeOwnAnswer.rawValue: "Type your own answer",
        Key.questionCustomPlaceholder.rawValue: "Type your answer...",
        Key.questionDismiss.rawValue: "Dismiss",
        Key.questionSubmit.rawValue: "Submit",
        Key.questionBack.rawValue: "Back",
        Key.questionNext.rawValue: "Next",
        Key.questionOf.rawValue: "%d of %d",

        Key.toolReason.rawValue: "Reason",
        Key.toolCommandInput.rawValue: "Command / Input",
        Key.toolPath.rawValue: "Path",
        Key.toolOutput.rawValue: "Output",
        Key.toolOpenInFileTree.rawValue: "Open \"%@\" in File Tree",
        Key.toolOpenFile.rawValue: "Open File",
        Key.toolSelectFile.rawValue: "Select file to open",
        Key.toolImageFile.rawValue: "Image file",
        Key.toolReadFileAccessibilityLabel.rawValue: "Read file %@",
        Key.toolWriteFileAccessibilityLabel.rawValue: "Write file %@",
        Key.toolReadDirectoryAccessibilityLabel.rawValue: "Read directory %@",
        Key.folderEmptyTitle.rawValue: "Empty folder",
        Key.folderEmptyDescription.rawValue: "This directory has no entries.",

        Key.patchFilesChangedOne.rawValue: "%d file changed",
        Key.patchFilesChangedMany.rawValue: "%d files changed",

        Key.contextUsageHelp.rawValue: "Context usage",
        Key.contextUsageClose.rawValue: "Close",
        Key.contextUsageTitle.rawValue: "Context",
        Key.contextUsageSectionSession.rawValue: "Session",
        Key.contextUsageSectionModel.rawValue: "Model",
        Key.contextUsageSectionTokens.rawValue: "Tokens",
        Key.contextUsageSectionCost.rawValue: "Cost",
        Key.contextUsageTitleLabel.rawValue: "Title",
        Key.contextUsageIdLabel.rawValue: "ID",
        Key.contextUsageProviderLabel.rawValue: "Provider",
        Key.contextUsageModelLabel.rawValue: "Model",
        Key.contextUsageLimitLabel.rawValue: "Context limit",
        Key.contextUsageTotalLabel.rawValue: "Total",
        Key.contextUsageInputLabel.rawValue: "Input",
        Key.contextUsageOutputLabel.rawValue: "Output",
        Key.contextUsageReasoningLabel.rawValue: "Reasoning",
        Key.contextUsageCachedReadLabel.rawValue: "Cached read",
        Key.contextUsageCachedWriteLabel.rawValue: "Cached write",
        Key.contextUsageNoCostData.rawValue: "No cost data",
        Key.contextUsageLoadingConfig.rawValue: "Loading provider config...",
        Key.contextUsageNoUsageData.rawValue: "No usage data",
        Key.contextUsageConfigNotLoaded.rawValue: "Provider config not loaded",
        Key.contextUsageSectionThroughput.rawValue: "Throughput",
        Key.contextUsageThroughputAvg.rawValue: "Avg throughput",
        Key.contextUsageThroughputTime.rawValue: "Generation time",
        Key.contextUsageThroughputTokens.rawValue: "Generated tokens",
        Key.contextUsageThroughputNoData.rawValue: "No throughput data",
        Key.statusRoundsLabel.rawValue: "rounds",
        Key.statusToolsLabel.rawValue: "tool calls",
        Key.statusTokensLabel.rawValue: "tok",
        Key.statusCacheHitsLabel.rawValue: "cache hit",
        Key.statusSinceLastPromptLabel.rawValue: "since last prompt",
        Key.quotaTitle.rawValue: "Usage & Limits",
        Key.quotaDataSource.rawValue: "Data Source",
        Key.quotaNotLoaded.rawValue: "Quota data has not been loaded.",
        Key.quotaLoading.rawValue: "Loading quota data...",
        Key.quotaRefreshing.rawValue: "Refreshing cached quota data...",
        Key.quotaRefreshingProviders.rawValue: "Refreshing providers...",
        Key.quotaNoCachedData.rawValue: "No cached quota snapshot. Refresh AI Usage Dashboard on the host.",
        Key.quotaStale.rawValue: "Showing stale quota data",
        Key.quotaLastFetched.rawValue: "Last fetched",
        Key.quotaGeneratedAt.rawValue: "Generated at",
        Key.quotaRemainingFormat.rawValue: "%d%% left",
        Key.quotaUsedFormat.rawValue: "%d%% used",
        Key.quotaResetFormat.rawValue: "Resets %@",
        Key.quotaCurrentModelAccessibility.rawValue: "Current model quota: %@",

        Key.sessionTitle.rawValue: "Session",
        Key.sessionsTitle.rawValue: "Sessions",
        Key.sessionsEmptyTitle.rawValue: "No Sessions",
        Key.sessionsEmptyDescription.rawValue: "Tap + to create one, or pull to refresh for existing sessions.",
        Key.sessionsClose.rawValue: "Close",
        Key.sessionsNew.rawValue: "New",
        Key.sessionsUntitled.rawValue: "Untitled",
        Key.sessionsStatusBusy.rawValue: "Running",
        Key.sessionsIndicatorNeedsYou.rawValue: "Needs your attention",
        Key.sessionsIndicatorFailed.rawValue: "Last turn failed",
        Key.sessionsIndicatorUnread.rawValue: "Unread",
        Key.sessionsStatusRetry.rawValue: "Retrying",
        Key.sessionsStatusIdle.rawValue: "Idle",
        Key.sessionsStatusNeedAttention.rawValue: "Need attention",
        Key.sessionsActive.rawValue: "Active",
        Key.sessionsArchived.rawValue: "Archived",
        Key.sessionsArchive.rawValue: "Archive",
        Key.sessionsRestore.rawValue: "Restore",
        Key.sessionsLoadMore.rawValue: "Load more sessions",
        Key.sessionsActionFailedTitle.rawValue: "Session Action Failed",
        Key.sessionsDelete.rawValue: "Delete",

        Key.fileBinary.rawValue: "Binary file",
        Key.fileNoContent.rawValue: "No content",
        Key.filePreviewMode.rawValue: "Preview Mode",
        Key.fileNativePreview.rawValue: "Native Preview",
        Key.fileWebPreview.rawValue: "Web Preview",
        Key.fileMarkdownSource.rawValue: "Markdown Source",
        Key.contentImageDecodeFailed.rawValue: "Failed to decode image",
        Key.contentNoImageData.rawValue: "No image data",
        Key.markdownPreviewLoading.rawValue: "Loading preview...",
        Key.markdownWebPreviewLoading.rawValue: "Loading web preview...",
        Key.markdownWebPreviewLargeDocumentTitle.rawValue: "Large document",
        Key.markdownWebPreviewLargeDocumentDescription.rawValue: "This file is large. Web Preview may be slow or memory-heavy.",
        Key.markdownWebPreviewRenderAnyway.rawValue: "Render anyway",
        Key.markdownWebPreviewOpenNative.rawValue: "Open Native Preview",
        Key.markdownWebPreviewOpenSource.rawValue: "Open Markdown Source",
        Key.markdownWebPreviewFailedTitle.rawValue: "Web Preview failed",
        Key.markdownWebPreviewAssetsMissing.rawValue: "Web Preview assets missing from app bundle.",
        Key.markdownWebPreviewPayloadEncodeFailed.rawValue: "Failed to encode preview payload.",
        Key.markdownWebPreviewRenderCallFailed.rawValue: "Render call failed: %@",
        Key.markdownWebPreviewWebViewLoadFailed.rawValue: "WebView load failed: %@",
        Key.markdownWebPreviewWebViewProvisionalLoadFailed.rawValue: "WebView provisional load failed: %@",
        Key.markdownWebPreviewUnknownRenderError.rawValue: "Unknown render error",

        Key.errorConnectionFailed.rawValue: "Connection failed: %@",
        Key.errorServerError.rawValue: "Server error: %@",
        Key.errorInvalidResponse.rawValue: "Server returned invalid response",
        Key.errorUnauthorized.rawValue: "Unauthorized; check your credentials",
        Key.errorSessionNotFound.rawValue: "Session not found",
        Key.errorFileNotFound.rawValue: "File not found: %@",
        Key.errorOperationFailed.rawValue: "Operation failed: %@",
        Key.errorUnknown.rawValue: "Unknown error: %@",
        Key.errorInvalidBaseURL.rawValue: "Invalid base URL",
        Key.errorServerAddressEmpty.rawValue: "Server address is empty",
        Key.errorWanRequiresHttps.rawValue: "WAN address must use HTTPS",
        Key.errorUsingLanHttp.rawValue: "Using HTTP on LAN",
        Key.helpLanHttp.rawValue: "LAN: HTTP is allowed only on trusted local networks.",
        Key.helpWanHttp.rawValue: "WAN: HTTPS is required. HTTP will be blocked.",
        Key.helpTailscaleHttp.rawValue: "Tailscale does not require HTTPS; other WAN addresses still require HTTPS.",

        Key.activityRetrying.rawValue: "Retrying",
        Key.activityThinking.rawValue: "Thinking",
        Key.activityDelegating.rawValue: "Delegating",
        Key.activityPlanning.rawValue: "Planning",
        Key.activityGatheringContext.rawValue: "Gathering context",
        Key.activitySearchingCodebase.rawValue: "Searching codebase",
        Key.activitySearchingWeb.rawValue: "Searching web",
        Key.activityMakingEdits.rawValue: "Making edits",
        Key.activityRunningCommands.rawValue: "Running commands",
        Key.activityGatheringThoughts.rawValue: "Gathering thoughts",

        Key.configureTitle.rawValue: "Model & Agent",
        Key.configureModel.rawValue: "Model",
        Key.configureAgent.rawValue: "Agent",
        Key.configureNoAgents.rawValue: "No agents available",
        Key.configureModelSearchPlaceholder.rawValue: "Search models",
        Key.configureModelNoMatches.rawValue: "No matching models",
        Key.configureModelEmptyShortlist.rawValue: "Add models in Settings → Models.",
        Key.configureModelEditShortlist.rawValue: "Add, remove, or reorder in Settings",

        Key.todoPanelTitle.rawValue: "Todo",
        Key.todoPanelCompleted.rawValue: "%d/%d completed",
        Key.todoPanelEmpty.rawValue: "No todos yet",
        Key.todoUpdatedBadge.rawValue: "Todo updated · %d/%d",
    ]

    nonisolated private static let zh: [String: String] = [
        Key.expanded.rawValue: "已展开",
        Key.collapsed.rawValue: "已收起",
        Key.selected.rawValue: "已选中",
        Key.notSelected.rawValue: "未选中",
        Key.moveUp.rawValue: "上移",
        Key.moveDown.rawValue: "下移",
        Key.hostSaveAndConnect.rawValue: "保存并连接",
        Key.hostConnect.rawValue: "连接此主机",
        Key.hostDiscardTitle.rawValue: "放弃未保存的主机更改？",
        Key.hostDiscardChanges.rawValue: "放弃更改",
        Key.hostKeepEditing.rawValue: "继续编辑",
        Key.hostDiscardPairingWarning.rawValue: "放弃更改也会丢失配对凭据。已使用的配对码无法再次使用；如需稍后配对，请在服务器上生成新码。",
        Key.hostDiscardChangesWarning.rawValue: "你填写的主机信息将不会被保存。",
        Key.hostManualImport.rawValue: "导入 JSON 配置",
        Key.hostScanTitle.rawValue: "扫描配对码",
        Key.sessionsSearchLoaded.rawValue: "搜索已加载的会话",
        Key.sessionsSearchScope.rawValue: "搜索当前主机和项目中已加载的会话标题。加载更多可包含更早的会话。",
        Key.sessionsNoMatches.rawValue: "没有匹配的已加载会话",
        Key.sessionsDeleteConfirmation.rawValue: "删除会话？",
        Key.sessionsDeleteWarning.rawValue: "“%@”将从服务器永久删除，且无法撤销。如果以后可能需要，请改为归档。",
        Key.fileTreeEmpty.rawValue: "此工作区为空",
        Key.fileStatusAdded.rawValue: "已添加",
        Key.fileStatusDeleted.rawValue: "已删除",
        Key.fileStatusModified.rawValue: "已修改",
        Key.fileStatusUntracked.rawValue: "未跟踪",
        Key.chatConnectServer.rawValue: "连接服务器",
        Key.chatSend.rawValue: "发送消息",
        Key.chatAttachImage.rawValue: "添加图片",
        Key.chatStopRecording.rawValue: "停止录音",
        Key.questionGoTo.rawValue: "转到第 %d 个问题",
        Key.settingsOpenSystem.rawValue: "打开系统设置",
        Key.appChat.rawValue: "聊天",
        Key.appClose.rawValue: "关闭",
        Key.appDone.rawValue: "完成",
        Key.appLoading.rawValue: "加载中...",
        Key.appNoContent.rawValue: "暂无内容",
        Key.appError.rawValue: "错误",
        Key.appSearchFiles.rawValue: "搜索文件",
        Key.deepLinkOpening.rawValue: "正在打开会话…",
        Key.deepLinkInvalid.rawValue: "这个 OpenCode 会话链接无效。",
        Key.deepLinkSessionUnavailable.rawValue: "当前主机上找不到这个会话。它可能属于其他主机，或只存在于离线历史中。",
        Key.deepLinkOpenFailed.rawValue: "无法打开这个会话，请检查当前主机连接后重试。",
        Key.capabilityPermissionTitle.rawValue: "客户端能力",
        Key.capabilityHealthExportTitle.rawValue: "同步健康量化数据",
        Key.capabilityHealthExportDescription.rawValue: "将最新 HealthKit 数据导出到健康量化 App 已配置的服务器。",
        Key.capabilityWhatHappens.rawValue: "将执行的操作",
        Key.capabilityAgentNote.rawValue: "请求方 Agent 的说明",
        Key.capabilityReason.rawValue: "原因",
        Key.capabilityPermissionFooter.rawValue: "OpenCode 会生成一次性回调链接，链接不会返回健康明细。",
        Key.capabilityAllowOnce.rawValue: "仅这次允许",
        Key.capabilityAllowAlways.rawValue: "以后自动允许",
        Key.setupPlanTitle.rawValue: "连接你的服务器",
        Key.setupPlanSubtitle.rawValue: "OpenCodex 会直连你的 OpenCode 服务器。填入地址，或从下面的选项开始。",
        Key.setupPlanAddressPlaceholder.rawValue: "服务器地址，例如 192.168.1.10:4096",
        Key.setupPlanEnterToSend.rawValue: "回车发送",
        Key.setupPlanSend.rawValue: "发送",
        Key.setupPlanIdeasTitle.rawValue: "你可以试试",
        Key.setupPlanIdeaLocal.rawValue: "本地服务器",
        Key.setupPlanIdeaSSH.rawValue: "SSH 隧道",
        Key.setupPlanIdeaPaste.rawValue: "粘贴配对码",
        Key.setupPlanIdeaScan.rawValue: "扫描配对码",
        Key.capabilitySettingsTitle.rawValue: "客户端能力",
        Key.capabilityAllowedAutomatically.rawValue: "自动允许",
        Key.capabilityAllowedOtherHost.rawValue: "已授权给其他主机",
        Key.capabilityAskEveryTime.rawValue: "每次询问",
        Key.capabilityRevoke.rawValue: "撤销自动授权",
        Key.capabilitySettingsFooter.rawValue: "自动授权只允许导出健康数据，不授权分析或其他副作用。",
        Key.capabilityAlreadyRunning.rawValue: "健康数据同步已在进行。",
        Key.capabilityLaunchFailed.rawValue: "未安装健康量化 App，或无法打开。",
        Key.capabilityInvalidCallback.rawValue: "OpenCode 拒绝了无效或已过期的健康导出回调。",
        Key.capabilityContinuationFailed.rawValue: "健康数据已导出，但 OpenCode 无法继续原会话。",
        Key.commonOk.rawValue: "确定",
        Key.commonCancel.rawValue: "取消",
        Key.commonRetry.rawValue: "重试",
        Key.carTab.rawValue: "Ambient Mode",
        Key.navFiles.rawValue: "文件",
        Key.navSettings.rawValue: "设置",
        Key.sidebarHideSessions.rawValue: "隐藏会话栏",
        Key.sidebarShowSessions.rawValue: "显示会话栏",
        Key.contentRefreshHelp.rawValue: "刷新预览",

        Key.settingsTitle.rawValue: "设置",
        Key.settingsConnection.rawValue: "连接",
        Key.settingsManageHosts.rawValue: "管理主机",
        Key.settingsCheck.rawValue: "检查",
        Key.settingsChecking.rawValue: "正在检查…",
        Key.settingsWorkspace.rawValue: "工作区",
        Key.settingsProjectShort.rawValue: "项目",
        Key.settingsWorkspaceFooter.rawValue: "选择聊天中可用的项目和模型。",
        Key.settingsPreferences.rawValue: "偏好设置",
        Key.settingsInputVoice.rawValue: "输入与语音",
        Key.settingsAdvanced.rawValue: "高级设置",
        Key.settingsOpenCode.rawValue: "OpenCode",
        Key.settingsUsername.rawValue: "用户名",
        Key.settingsPassword.rawValue: "密码",
        Key.settingsConnected.rawValue: "已连接",
        Key.settingsDisconnected.rawValue: "未连接",
        Key.settingsTestConnection.rawValue: "测试连接",
        Key.settingsPublicKeyCopied.rawValue: "公钥已复制",
        Key.settingsSshSetupGuideTitle.rawValue: "SSH 网关设置",
        Key.settingsSshSetupGuideBody.rawValue: "1. 点击复制公钥，把它发给服务器管理员。\n\n2. 管理员把这台设备的 key 加到你的用户下面，并给你 Host、SSH Port、Username 和分配的 Remote Port。opencode-private-host 默认 Username 通常是 opencode，SSH Port 通常是 8006，第一个用户的 Remote Port 通常是 19001。\n\n3. 在这里填入这些值，开启 SSH Tunnel，然后点击“将服务器地址设置为 127.0.0.1:4096”。\n\n4. 点击测试连接。App 会访问本机 127.0.0.1:4096，SSH 隧道会把它转发到你的私有 OpenCode 容器。\n\n5. 如果 provider auth 还没配置，请让管理员先在 OpenCode Web UI 里完成第一次 provider 登录。",
        Key.settingsAutoTheme.rawValue: "自动",
        Key.settingsLightTheme.rawValue: "亮色",
        Key.settingsDarkTheme.rawValue: "暗色",
        Key.settingsAppearance.rawValue: "外观",
        Key.settingsTheme.rawValue: "主题",
        Key.settingsLayout.rawValue: "布局模式",
        Key.settingsLayoutAutomatic.rawValue: "自动",
        Key.settingsLayoutFocus.rawValue: "专注",
        Key.settingsLayoutFooter.rawValue: "专注模式在大屏显示单一内容，聊天中打开文件仍保留输入区。",
        Key.settingsVoiceFirst.rawValue: "语音优先",
        Key.settingsComposerActionSide.rawValue: "输入区操作按钮",
        Key.settingsComposerLeftHand.rawValue: "左手模式",
        Key.settingsComposerRightHand.rawValue: "右手模式",
        Key.settingsShowImageButton.rawValue: "显示图像按钮",
        Key.settingsVoiceFirstFooter.rawValue: "开启后轻点草稿不弹键盘，仍可粘贴文本，点键盘按钮进入编辑。",
        Key.settingsSpeechRecognition.rawValue: "语音识别",
        Key.settingsAbout.rawValue: "关于",
        Key.settingsServerVersion.rawValue: "服务器版本",
        Key.settingsOpenSourceLicences.rawValue: "开源许可证",
        Key.settingsOpenSourceLicencesMissing.rawValue: "此构建缺少许可证声明。",
        Key.settingsExperimentalFeatures.rawValue: "实验性功能",
        Key.settingsCarMode.rawValue: "Ambient Mode",
        Key.settingsAppleOnDevice.rawValue: "Apple 设备端识别",
        Key.settingsAppleOnDeviceFooter.rawValue: "转写完全在这台设备上用 Apple 语音识别完成，不上传任何数据，也无需账号。",
        Key.settingsModelShortlist.rawValue: "模型",
        Key.settingsModelShortlistFooter.rawValue: "聊天栏只显示这份短名单。从已连接的 server 目录里搜索添加。",
        Key.settingsModelShortlistEmpty.rawValue: "还没有模型。点右上角 + 搜索添加。",
        Key.settingsModelShortlistAdd.rawValue: "添加模型",
        Key.settingsModelShortlistSearch.rawValue: "搜索目录",
        Key.settingsModelShortlistEditName.rawValue: "短名称",
        Key.settingsModelShortlistShortName.rawValue: "工具栏显示名",
        Key.settingsModelShortlistAddSelected.rawValue: "添加",
        Key.settingsModelShortlistCatalogEmpty.rawValue: "先连接 server 才能加载模型目录。",
        Key.settingsModelShortlistHint.rawValue: "聊天栏按这份名单的顺序切换。按左边手柄排序，左滑删除。要添加，点右上角加号。",
        Key.settingsModelShortlistSearchClear.rawValue: "清空搜索",
        Key.settingsModelShortlistReorder.rawValue: "排序",
        Key.settingsModelShortlistCatalogHint.rawValue: "可以搜索，点选模型，再点添加写入名单。要删除，请回到上一页左滑。",
        Key.settingsAIUsageDashboard.rawValue: "AI 用量面板",
        Key.settingsAIUsageDashboardURL.rawValue: "面板地址（可选）",
        Key.settingsAIUsageDashboardFooter.rawValue: "留空时不显示任何 quota 界面。可填写面板根地址或完整的 /api/v1/quotas 地址。",
        Key.settingsRotateKeyTitle.rawValue: "要更换 SSH 密钥吗？",
        Key.settingsRotateKeyPrompt.rawValue: "这将为本设备生成一对新密钥。再次使用 SSH Tunnel hosts 前，请同步更新 SSH server 上的公钥。",
        Key.settingsPublicKeyTitle.rawValue: "你的公钥",
        Key.settingsPublicKeyFooter.rawValue: "把这个公钥发给服务器管理员。不要分享私钥。",
        Key.settingsCopyToClipboard.rawValue: "复制到剪贴板",
        Key.settingsPublicKeyCopyFailed.rawValue: "无法加载 SSH 公钥。",
        Key.settingsPublicKeyRotate.rawValue: "更换密钥",
        Key.settingsPublicKeyErrorTitle.rawValue: "公钥错误",
        Key.settingsRotate.rawValue: "更换",
        Key.settingsTrustHostKeyTitle.rawValue: "信任新的 SSH Host Key？",
        Key.settingsTrustHostKeyMessage.rawValue: "%@:%d 返回了不同的 host key。\n\n之前：%@\n新的：%@\n\n只有在你确认服务器刚重建或重装时，才信任这个新 key。",
        Key.settingsTrustHostKeyConfirm.rawValue: "信任并重连",
        Key.errorServerAddressEmpty.rawValue: "服务器地址不能为空",
        Key.errorWanRequiresHttps.rawValue: "WAN 地址必须使用 HTTPS",
        Key.errorUsingLanHttp.rawValue: "正在使用 LAN HTTP",
        Key.settingsProject.rawValue: "项目（工作区）",
        Key.settingsProjectServerDefault.rawValue: "服务器默认",
        Key.settingsProjectCustomPath.rawValue: "自定义路径",
        Key.settingsProjectCustomPathPlaceholder.rawValue: "/path/to/project",
        Key.settingsProjectMismatchWarning.rawValue: "服务器默认项目是 {server}。新会话会创建在 {server}，而不是 {effective}。如需在 {effective} 创建会话，请从命令行在该项目目录启动 OpenCode。",
        Key.settingsLanguage.rawValue: "语言",
        Key.settingsLanguageSystem.rawValue: "跟随系统",
        Key.settingsLanguageEnglish.rawValue: "英文",
        Key.settingsLanguageChinese.rawValue: "中文",
        Key.chatCreateDisabledHint.rawValue: "只有选择“服务器默认项目”时才能新建会话。如需在其他项目中创建会话，请从命令行在对应目录启动 OpenCode，然后在这里选择“服务器默认”。",

        Key.hostCurrent.rawValue: "当前主机",
        Key.hostCurrentFooter.rawValue: "Host 表示一个 OpenCode 环境，可以直连 LAN、Tailscale、VPN、HTTPS，也可以通过 SSH 隧道访问。",
        Key.hostNoHost.rawValue: "未配置 Host",
        Key.hostAddToConnect.rawValue: "添加 Host 后连接",
        Key.hostHosts.rawValue: "主机",
        Key.hostDelete.rawValue: "删除",
        Key.hostDuplicate.rawValue: "复制",
        Key.hostEdit.rawValue: "编辑",
        Key.hostAdd.rawValue: "添加 Host",
        Key.hostDeviceKey.rawValue: "设备密钥",
        Key.hostCopyDevicePublicKey.rawValue: "复制本设备公钥",
        Key.hostDeviceKeyFooter.rawValue: "SSH Tunnel hosts 复用同一把设备公钥。Direct hosts 不需要。",
        Key.hostErrorTitle.rawValue: "Host 错误",
        Key.hostNeverConnected.rawValue: "从未连接",
        Key.hostLastUsed.rawValue: "上次使用 %@",
        Key.hostOverview.rawValue: "概览",
        Key.hostName.rawValue: "名称",
        Key.hostTransport.rawValue: "连接方式",
        Key.hostOpenCodeURL.rawValue: "OpenCode 地址",
        Key.hostStatus.rawValue: "状态",
        Key.hostManagedBySSHTunnel.rawValue: "由 SSH 隧道管理",
        Key.hostSavedHost.rawValue: "已保存 Host",
        Key.hostSSHTunnel.rawValue: "SSH 隧道",
        Key.hostSSHGateway.rawValue: "SSH 网关",
        Key.hostGatewayHost.rawValue: "网关地址",
        Key.hostSSHPort.rawValue: "SSH 端口",
        Key.hostSSHUsername.rawValue: "SSH 用户名",
        Key.hostAssignedRemotePort.rawValue: "分配的远端端口",
        Key.hostConnectionDiagnostics.rawValue: "连接诊断",
        Key.hostUseThisHost.rawValue: "使用此主机",
        Key.hostConfigCopied.rawValue: "主机配置已复制",
        Key.hostCopyConfigJSON.rawValue: "复制 Host Config JSON",
        Key.hostNotFound.rawValue: "找不到 Host",
        Key.hostImportConfig.rawValue: "导入 Host Config",
        Key.hostImportFooter.rawValue: "粘贴管理员提供的配置 JSON。导入只填写此表单，保存后才会提交配置。",
        Key.hostConnectionType.rawValue: "连接类型",
        Key.hostTransportFooter.rawValue: "直连适用于局域网、VPN、Tailscale 或 HTTPS。SSH 隧道适用于放在 SSH 网关后的 OpenCode 服务器。",
        Key.hostSSHGatewayFooter.rawValue: "这些值由 OpenCode host 管理员提供。保存后 app 会通过本地隧道连接。",
        Key.hostDeviceKeySendFooter.rawValue: "测试前把这个公钥发给服务器管理员。不要分享私钥。",
        Key.hostBasicAuth.rawValue: "Basic Auth",
        Key.hostSaveHelp.rawValue: "保存会存储配置并选择此主机。保存并连接还会检查连接。取消仅放弃尚未保存的更改。",
        Key.hostPairSection.rawValue: "与 OpenCode 配对",
        Key.hostPairScanQR.rawValue: "扫描二维码",
        Key.hostPairPasteLink.rawValue: "或粘贴配对链接",
        Key.hostPairLinkPlaceholder.rawValue: "http://host:port/auth/connect/…",
        Key.hostPairRedeeming.rawValue: "正在配对…",
        Key.hostPairPaired.rawValue: "已与 %@ 配对",
        Key.hostPairReplaceTitle.rawValue: "替换服务器地址？",
        Key.hostPairReplaceConfirm.rawValue: "替换",
        Key.hostPairReplaceMessage.rawValue: "配对码指向 %@，当前主机指向 %@。要替换地址并使用新的凭据吗？",
        Key.hostPairInvalidLink.rawValue: "这不是 OpenCode 配对链接。",
        Key.hostPairCameraDenied.rawValue: "相机权限未开启。请在系统设置中开启，或直接粘贴配对链接。",
        Key.hostPairCameraHint.rawValue: "在服务器上运行 `opencode pair`，然后用相机对准二维码。",
        Key.hostPairCameraUnavailable.rawValue: "此设备没有相机，请直接粘贴配对链接。",
        Key.hostSave.rawValue: "保存",
        Key.hostEditTitle.rawValue: "编辑 Host",
        Key.hostAddTitle.rawValue: "添加 Host",
        Key.hostTitle.rawValue: "主机",
        Key.hostTransportDirect.rawValue: "直连",
        Key.hostUntitled.rawValue: "未命名主机",
        Key.hostDefaultLocalName.rawValue: "本地 OpenCode",
        Key.hostDefaultSSHName.rawValue: "SSH OpenCode",
        Key.hostDuplicateName.rawValue: "%@ 副本",
        Key.hostImportErrorDirectRequiresServerURL.rawValue: "直连配置需要 serverURL。",
        Key.hostImportErrorSSHTunnelRequiresSSHSettings.rawValue: "SSH 隧道配置需要 ssh 设置。",
        Key.hostImportErrorInvalidUTF8.rawValue: "Host config 不是有效的 UTF-8。",
        Key.hostExportErrorEncodeConfigJSON.rawValue: "无法生成 Host Config JSON。",
        Key.hostConnectionErrorInvalidURL.rawValue: "OpenCode 地址无效，请检查主机地址和端口。",
        Key.hostConnectionErrorUnsupportedServer.rawValue: "该地址不是 OpenCode 服务器，没有响应 OpenCode API。",
        Key.hostConnectionErrorBasicAuthRejected.rawValue: "OpenCode 拒绝了 Basic Auth。",
        Key.hostConnectionErrorHTTPStatus.rawValue: "OpenCode 返回 HTTP %d。请检查服务器日志或服务商配置。",
        Key.hostConnectionErrorCannotConnect.rawValue: "无法连接到 OpenCode。请检查网络是否可达，以及服务器是否正在运行。",
        Key.hostConnectionErrorTimedOut.rawValue: "连接超时。请检查主机、端口、VPN/Tailscale 和防火墙。",
        Key.hostConnectionErrorDNS.rawValue: "无法解析主机名。请检查网关或服务器地址拼写。",
        Key.hostConnectionErrorNetwork.rawValue: "网络错误：%@",
        Key.hostConnectionErrorHealthCheckFailed.rawValue: "OpenCode 服务状态检查失败。请确认服务器正在运行且可以访问。",
        Key.hostConnectionErrorGeneric.rawValue: "连接失败。请检查主机配置后重试。",
        Key.hostDiagnosticCheckingHealth.rawValue: "正在检查 OpenCode 服务状态...",
        Key.hostDiagnosticCheckingHealthURL.rawValue: "正在检查 %@/global/health...",
        Key.hostDiagnosticConnectingSSHGateway.rawValue: "正在连接 SSH 网关...",
        Key.hostDiagnosticHintConfirmGateway.rawValue: "请确认网关地址、SSH 端口、设备公钥和网络可达性。",
        Key.hostDiagnosticSSHTunnelFailed.rawValue: "SSH 隧道失败：%@",
        Key.hostDiagnosticHintCopyDeviceKeyAgain.rawValue: "如果服务器还没有授权这台设备，请重新复制本设备公钥给管理员。",
        Key.hostDiagnosticTunnelReadyCheckingHealth.rawValue: "SSH 隧道已就绪，正在检查 OpenCode 服务状态...",
        Key.hostDiagnosticHintURLFormat.rawValue: "请使用 host:port、http://host:port 或 https://host:port。",
        Key.hostDiagnosticConnectedToOpenCode.rawValue: "已连接到 OpenCode%@。",
        Key.hostDiagnosticHealthUnhealthy.rawValue: "OpenCode 服务状态检查返回异常。",
        Key.hostDiagnosticHintCheckServerLogs.rawValue: "请检查 OpenCode 服务进程和日志。",
        Key.hostDiagnosticHintVerifyHostConfig.rawValue: "SSH 隧道主机请先检查网关参数和设备密钥；直连主机请确认这台设备能访问该地址。",
        Key.hostDiagnosticHintBasicAuth.rawValue: "请检查这个主机的用户名和密码。",
        Key.hostDiagnosticLocalListenerFailed.rawValue: "本地监听器失败：%@",
        Key.hostValidationVPSHostRequired.rawValue: "VPS 地址不能为空",
        Key.hostValidationSSHUsernameRequired.rawValue: "SSH 用户名不能为空",
        Key.hostValidationSSHPortPositive.rawValue: "SSH 端口必须大于 0",
        Key.hostValidationAssignedRemotePortPositive.rawValue: "分配的远端端口必须大于 0",
        Key.hostSSHTunnelUnavailableVisionOS.rawValue: "visionOS 版本暂不支持 SSH 隧道。请改用直连 OpenCode 服务器。",
        Key.sshErrorConnectionFailed.rawValue: "连接失败：%@",
        Key.sshErrorAuthenticationFailed.rawValue: "认证失败。请确认服务器已添加你的公钥。",
        Key.sshErrorKeyNotFound.rawValue: "找不到 SSH 密钥。请先生成密钥对。",
        Key.sshErrorInvalidKeyFormat.rawValue: "SSH 密钥格式无效。",
        Key.sshErrorTunnelFailed.rawValue: "隧道失败：%@",
        Key.sshErrorHostKeyMismatch.rawValue: "Host key 不匹配。预期 %@，实际 %@。这可能是中间人攻击，也可能是服务器重装。请重置信任主机，并核对 fingerprint 后再连接。",
        Key.sshErrorKeyUnavailable.rawValue: "SSH 密钥暂时不可用。请解锁设备后重试。",
        Key.keychainErrorUnhandledStatus.rawValue: "Keychain 操作失败（OSStatus %d）。",

        Key.connectionPhaseIdle.rawValue: "空闲",
        Key.connectionPhaseSSHGateway.rawValue: "正在连接 SSH 网关",
        Key.connectionPhaseSSHAuth.rawValue: "正在用设备密钥认证",
        Key.connectionPhaseLocalTunnel.rawValue: "正在启动本地隧道",
        Key.connectionPhaseHealth.rawValue: "正在检查 OpenCode 服务状态",
        Key.connectionPhaseBootstrap.rawValue: "正在加载项目和会话",
        Key.connectionPhaseConnected.rawValue: "已连接",
        Key.connectionPhaseFailed.rawValue: "连接失败",

        Key.chatInputPlaceholder.rawValue: "输入你的问题...",
        Key.chatPaste.rawValue: "粘贴",
        Key.chatKeyboard.rawValue: "键盘",
        Key.chatDismissKeyboard.rawValue: "收起键盘",
        Key.chatSendFailed.rawValue: "发送失败",
        Key.chatRenameSession.rawValue: "重命名会话",
        Key.chatRenameSessionPlaceholder.rawValue: "输入新标题",
        Key.chatTitleField.rawValue: "标题",
        Key.chatSpeechTitle.rawValue: "语音识别",
        Key.chatSelectSessionFirst.rawValue: "请选择一个会话",
        Key.chatSessionBusyMessage.rawValue: "会话正在运行中，消息尚未可见，正在刷新中…",
        Key.chatNoMessages.rawValue: "暂无消息",
        Key.chatGreeting.rawValue: "有什么可以帮你的？",
        Key.chatTurnCompleted.rawValue: "已完成",
        Key.speechApplePermissionDenied.rawValue: "语音识别权限被拒绝：请在“设置 > 隐私与安全性 > 语音识别”中开启。",
        Key.speechAppleUnavailable.rawValue: "此设备不支持设备端语音识别。",
        Key.speechAppleOnDeviceUnavailable.rawValue: "你的语言暂不支持设备端语音识别。请到“设置 > 语音识别”选择云端方案。",
        Key.speechAppleNoSpeech.rawValue: "录音中没有识别到语音。",
        Key.chatSpeechTesting.rawValue: "AI Builder 正在测试连接，请稍候。",
        Key.chatSpeechNotPassed.rawValue: "AI Builder 连接未通过测试：请先到 Settings -> Speech Recognition 点击 Test Connection，确认 OK 后再录音。",
        Key.chatSpeechTapToSpeak.rawValue: "点击说话",
        Key.chatSpeechListening.rawValue: "正在听…",
        Key.chatSpeechTranscriptWillAppear.rawValue: "转写内容会显示在这里…",
        Key.chatSpeechTranscribing.rawValue: "正在转写…",
        Key.chatSpeechTranscribingHint.rawValue: "正在完成转写…",
        Key.chatSpeechPreservedAudio.rawValue: "音频已保留，可重试这段。",
        Key.chatSpeechStopWaiting.rawValue: "停止转写等待",
        Key.chatSpeechRetrySegment.rawValue: "重试这段",
        Key.chatSpeechDiscardAudio.rawValue: "丢弃音频",
        Key.chatAbortAgent.rawValue: "中断智能体",
        Key.chatAgentRunning.rawValue: "智能体正在运行",
        Key.chatAgentWorking.rawValue: "处理中",
        Key.chatBackgroundTasksOne.rawValue: "子代理正在运行",
        Key.chatBackgroundTasksMany.rawValue: "%d 个子代理正在运行",
        Key.chatBackgroundTasksAccessibility.rawValue: "后台子代理正在运行，轻点打开子代理会话",
        Key.chatMicrophoneDenied.rawValue: "未授权麦克风权限",
        Key.chatSessionStatusBusy.rawValue: "运行中",
        Key.chatSessionStatusRetrying.rawValue: "重试中",
        Key.chatSessionStatusIdle.rawValue: "空闲",
        Key.chatPullToLoadMore.rawValue: "下拉加载更多历史消息",
        Key.chatLoadingMoreHistory.rawValue: "正在加载更多历史消息...",
        Key.chatLargeMessagePreviewNotice.rawValue: "消息较长：共 %@ 个字符。为保持流畅，已跳过 Markdown 渲染。",
        Key.chatLargeMessageTruncatedNotice.rawValue: "消息较长：当前只显示前 %@ / %@ 个字符。为保持流畅，已跳过 Markdown 渲染。",
        Key.chatSelectText.rawValue: "选择文本",
        Key.chatCopyMessage.rawValue: "复制整条消息",
        Key.chatEditFromHere.rawValue: "从这里编辑",
        Key.carTitle.rawValue: "Ambient Mode",
        Key.carReady.rawValue: "可以说话",
        Key.carFinalizing.rawValue: "正在完成转写",
        Key.carWorking.rawValue: "OpenCode 正在处理",
        Key.carNeedsConfirmation.rawValue: "需要确认",
        Key.carFailed.rawValue: "需要处理",
        Key.carStartSpeaking.rawValue: "开始说话",
        Key.carStopAndSend.rawValue: "停止并发送",
        Key.carStopSpeaking.rawValue: "停止朗读",
        Key.carStopResponse.rawValue: "停止响应",
        Key.carSpeakConfirmation.rawValue: "说确认或取消",
        Key.carEmptyPrompt.rawValue: "可以询问家里状态、消息、路况，或要去哪里。",
        Key.carNewSession.rawValue: "新建 Ambient Mode 会话",
        Key.carNewSessionPrompt.rawValue: "新建 Ambient Mode 会话并离开当前上下文？",
        Key.carConfirmUtterance.rawValue: "确认。",
        Key.carCancelUtterance.rawValue: "取消。",
        Key.carNotConnected.rawValue: "使用 Ambient Mode 前，请先连接 OpenCode。",
        Key.carServerDefaultRequired.rawValue: "Ambient Mode 目前只能在服务器默认工作区新建会话。",
        Key.carInvalidResponse.rawValue: "OpenCode 返回的 Ambient Mode 响应无效。",
        Key.carUnsupportedAction.rawValue: "OpenCode 请求了不支持的客户端操作。",
        Key.carMapsUnavailable.rawValue: "Apple 地图无法打开这条路线。",
        Key.carTranscriptionFailed.rawValue: "无法完成这段录音的转写。",
        Key.carVoiceMicrophoneDenied.rawValue: "Ambient 模式需要麦克风权限。",
        Key.carVoiceReady.rawValue: "准备就绪",
        Key.carVoiceListening.rawValue: "正在聆听",
        Key.carVoiceThinking.rawValue: "正在思考",
        Key.carVoiceSpeaking.rawValue: "正在说话",
        Key.carVoiceUnavailable.rawValue: "语音不可用：%@",
        Key.carVoiceYou.rawValue: "你",
        Key.carVoiceOpenCode.rawValue: "OpenCode",
        Key.carVoiceStart.rawValue: "开始聆听",
        Key.carVoiceStop.rawValue: "停止聆听",
        Key.carVoiceEnd.rawValue: "结束对话",
        Key.carVoicePermissionAsk.rawValue: "助手需要运行 %@ 的权限。说是允许一次，说不拒绝。",
        Key.carVoicePermissionAllowed.rawValue: "已允许。",
        Key.carVoicePermissionRefused.rawValue: "已拒绝。",
        Key.carLiveModeMenuTitle.rawValue: "语音模式",
        Key.carLiveModeRealtime.rawValue: "实时语音",
        Key.carLiveModeTurnByTurn.rawValue: "逐句语音",
        Key.carLiveEmptyConversation.rawValue: "暂无对话",
        Key.chatForkFromHere.rawValue: "从这里分叉",
        Key.chatThinkingCard.rawValue: "思考",
        Key.taskNotificationCompleted.rawValue: "已完成",
        Key.taskNotificationFailed.rawValue: "失败",
        Key.taskNotificationOpenSession.rawValue: "打开子代理会话",
        Key.taskNotificationNoOutput.rawValue: "无输出",
        Key.attachmentImageTitle.rawValue: "图片",
        Key.attachmentFileTitle.rawValue: "附件",
        Key.attachmentRemoveImageAccessibilityLabel.rawValue: "移除图片",
        Key.attachmentImageReadFailed.rawValue: "无法读取所选图片。",
        Key.attachmentImageTooLargeAfterCompression.rawValue: "图片压缩后仍过大（%@ MB）。请选择更小的图片。",

        Key.permissionAllowOnce.rawValue: "允许一次",
        Key.permissionAllowAlways.rawValue: "始终允许",
        Key.permissionReject.rawValue: "拒绝",
        Key.permissionAgentRequest.rawValue: "来自 Agent 的请求",
        Key.questionTitle.rawValue: "提问",
        Key.questionFromAgent.rawValue: "来自 Agent 的提问",
        Key.questionSingleHint.rawValue: "选择一个选项",
        Key.questionMultiHint.rawValue: "选择一个或多个选项",
        Key.questionTypeOwnAnswer.rawValue: "输入自定义答案",
        Key.questionCustomPlaceholder.rawValue: "输入你的答案...",
        Key.questionDismiss.rawValue: "跳过",
        Key.questionSubmit.rawValue: "提交",
        Key.questionBack.rawValue: "上一步",
        Key.questionNext.rawValue: "下一步",
        Key.questionOf.rawValue: "第 %d 题，共 %d 题",

        Key.toolReason.rawValue: "原因",
        Key.toolCommandInput.rawValue: "命令 / 输入",
        Key.toolPath.rawValue: "路径",
        Key.toolOutput.rawValue: "输出",
        Key.toolOpenInFileTree.rawValue: "在文件树中打开“%@”",
        Key.toolOpenFile.rawValue: "打开文件",
        Key.toolSelectFile.rawValue: "选择要打开的文件",
        Key.toolImageFile.rawValue: "图片文件",
        Key.toolReadFileAccessibilityLabel.rawValue: "读取文件 %@",
        Key.toolWriteFileAccessibilityLabel.rawValue: "写入文件 %@",
        Key.toolReadDirectoryAccessibilityLabel.rawValue: "读取目录 %@",
        Key.folderEmptyTitle.rawValue: "文件夹为空",
        Key.folderEmptyDescription.rawValue: "此目录没有条目。",

        Key.patchFilesChangedOne.rawValue: "%d 个文件已变更",
        Key.patchFilesChangedMany.rawValue: "%d 个文件已变更",

        Key.changesScopeTurn.rawValue: "本轮",
        Key.changesScopeSession.rawValue: "本次会话",
        Key.changesAdded.rawValue: "+%d",
        Key.changesDeleted.rawValue: "−%d",
        Key.changesOpenInFiles.rawValue: "在文件中打开",
        Key.changesLoadingDiff.rawValue: "正在读取差异…",
        Key.changesDiffUnavailable.rawValue: "无法加载差异",
        Key.changesSectionTitle.rawValue: "变更",
        Key.changesSectionSubtitle.rawValue: "本次会话",
        Key.changesBadgeAdded.rawValue: "新增",
        Key.changesBadgeModified.rawValue: "修改",
        Key.changesBadgeDeleted.rawValue: "删除",
        Key.changesAccessibilityLabel.rawValue: "%d 个文件已变更，新增 %d 行，删除 %d 行",
        Key.changesFileAccessibility.rawValue: "%@，新增 %d 行，删除 %d 行",
        Key.changesNoDiffForFile.rawValue: "该文件没有差异内容",
        Key.projectMemoryTitle.rawValue: "项目记忆",
        Key.projectMemorySectionSubtitle.rawValue: "注入到每一次 Agent 回合",
        Key.projectMemoryExplains.rawValue: "该文件会注入到每一次 Agent 回合，它是 Agent 在会话之间记住你的项目的方式。",
        Key.projectMemoryPresent.rawValue: "%@ · %d 行",
        Key.projectMemoryAbsent.rawValue: "尚未建立项目记忆",
        Key.projectMemoryUnreadable.rawValue: "无法读取 %@",
        Key.projectMemoryLoading.rawValue: "正在读取项目记忆…",
        Key.projectMemoryImprove.rawValue: "让 Agent 完善",
        Key.projectMemoryImproveBusy.rawValue: "Agent 正忙",
        Key.projectMemoryRestore.rawValue: "恢复上一版本",
        Key.projectMemoryReviewTitle.rawValue: "审阅变更",
        Key.projectMemoryChanged.rawValue: "Agent 修改了该文件。",
        Key.projectMemoryDeleted.rawValue: "Agent 删除了该文件。",
        Key.projectMemoryCreated.rawValue: "Agent 创建了该文件。",
        Key.projectMemoryWorking.rawValue: "Agent 正在更新项目记忆…",
        Key.projectMemoryRestoreNote.rawValue: "Agent 通过重写文件来恢复，结果可能与你接受的版本略有出入。",
        Key.projectMemoryEmptyContent.rawValue: "该文件为空。",
        Key.projectMemoryFileName.rawValue: "AGENTS.md",
        Key.projectMemoryServerDefault.rawValue: "服务器默认目录",
        Key.projectMemoryNotText.rawValue: "该文件不是文本。",
        Key.projectMemoryBackToFile.rawValue: "返回文件",
        Key.projectMemoryKeep.rawValue: "保留此版本",
        Key.projectMemoryActionFailed.rawValue: "无法向 Agent 发出请求，请检查连接后重试。",

        Key.contextUsageHelp.rawValue: "上下文用量",
        Key.contextUsageClose.rawValue: "关闭",
        Key.contextUsageTitle.rawValue: "上下文",
        Key.contextUsageSectionSession.rawValue: "会话",
        Key.contextUsageSectionModel.rawValue: "模型",
        Key.contextUsageSectionTokens.rawValue: "令牌",
        Key.contextUsageSectionCost.rawValue: "成本",
        Key.contextUsageTitleLabel.rawValue: "标题",
        Key.contextUsageIdLabel.rawValue: "ID",
        Key.contextUsageProviderLabel.rawValue: "提供商",
        Key.contextUsageModelLabel.rawValue: "模型名",
        Key.contextUsageLimitLabel.rawValue: "上下文上限",
        Key.contextUsageTotalLabel.rawValue: "总计",
        Key.contextUsageInputLabel.rawValue: "输入",
        Key.contextUsageOutputLabel.rawValue: "输出",
        Key.contextUsageReasoningLabel.rawValue: "推理",
        Key.contextUsageCachedReadLabel.rawValue: "缓存读",
        Key.contextUsageCachedWriteLabel.rawValue: "缓存写",
        Key.contextUsageNoCostData.rawValue: "无成本数据",
        Key.contextUsageLoadingConfig.rawValue: "正在加载服务商配置...",
        Key.contextUsageNoUsageData.rawValue: "无使用数据",
        Key.contextUsageConfigNotLoaded.rawValue: "未加载服务商配置",
        Key.contextUsageSectionThroughput.rawValue: "生成速率",
        Key.contextUsageThroughputAvg.rawValue: "平均速率",
        Key.contextUsageThroughputTime.rawValue: "生成耗时",
        Key.contextUsageThroughputTokens.rawValue: "生成令牌",
        Key.contextUsageThroughputNoData.rawValue: "无速率数据",
        Key.statusRoundsLabel.rawValue: "轮",
        Key.statusToolsLabel.rawValue: "工具",
        Key.statusTokensLabel.rawValue: "token",
        Key.statusCacheHitsLabel.rawValue: "缓存命中",
        Key.statusSinceLastPromptLabel.rawValue: "距上次提问",
        Key.quotaTitle.rawValue: "用量与限额",
        Key.quotaDataSource.rawValue: "数据来源",
        Key.quotaNotLoaded.rawValue: "尚未加载 quota 数据。",
        Key.quotaLoading.rawValue: "正在加载 quota 数据...",
        Key.quotaRefreshing.rawValue: "正在刷新缓存的 quota 数据...",
        Key.quotaRefreshingProviders.rawValue: "正在从服务商更新数据...",
        Key.quotaNoCachedData.rawValue: "没有缓存的 quota 快照。请先在主机上刷新 AI Usage Dashboard。",
        Key.quotaStale.rawValue: "正在显示过期 quota 数据",
        Key.quotaLastFetched.rawValue: "上次获取",
        Key.quotaGeneratedAt.rawValue: "生成时间",
        Key.quotaRemainingFormat.rawValue: "剩余 %d%%",
        Key.quotaUsedFormat.rawValue: "已用 %d%%",
        Key.quotaResetFormat.rawValue: "%@ 重置",
        Key.quotaCurrentModelAccessibility.rawValue: "当前模型 quota：%@",

        Key.sessionTitle.rawValue: "会话",
        Key.sessionsTitle.rawValue: "会话",
        Key.sessionsEmptyTitle.rawValue: "暂无会话",
        Key.sessionsEmptyDescription.rawValue: "点击右上角新建，或下拉刷新获取已有 Session",
        Key.sessionsClose.rawValue: "关闭",
        Key.sessionsNew.rawValue: "新建",
        Key.sessionsUntitled.rawValue: "无标题",
        Key.sessionsStatusBusy.rawValue: "运行中",
        Key.sessionsIndicatorNeedsYou.rawValue: "需要你处理",
        Key.sessionsIndicatorFailed.rawValue: "上一轮失败",
        Key.sessionsIndicatorUnread.rawValue: "有新内容未读",
        Key.sessionsStatusRetry.rawValue: "重试中",
        Key.sessionsStatusIdle.rawValue: "空闲",
        Key.sessionsStatusNeedAttention.rawValue: "需要关注",
        Key.sessionsActive.rawValue: "活跃",
        Key.sessionsArchived.rawValue: "已归档",
        Key.sessionsArchive.rawValue: "归档",
        Key.sessionsRestore.rawValue: "恢复",
        Key.sessionsLoadMore.rawValue: "加载更多会话",
        Key.sessionsActionFailedTitle.rawValue: "会话操作失败",
        Key.sessionsDelete.rawValue: "删除",

        Key.fileBinary.rawValue: "二进制文件",
        Key.fileNoContent.rawValue: "无内容",
        Key.filePreviewMode.rawValue: "预览方式",
        Key.fileNativePreview.rawValue: "原生预览",
        Key.fileWebPreview.rawValue: "Web 预览",
        Key.fileMarkdownSource.rawValue: "Markdown 源码",
        Key.contentImageDecodeFailed.rawValue: "图片解码失败",
        Key.contentNoImageData.rawValue: "没有图片数据",
        Key.markdownPreviewLoading.rawValue: "正在加载预览...",
        Key.markdownWebPreviewLoading.rawValue: "正在加载 Web 预览...",
        Key.markdownWebPreviewLargeDocumentTitle.rawValue: "文档较大",
        Key.markdownWebPreviewLargeDocumentDescription.rawValue: "这个文件较大，Web 预览可能较慢或占用较多内存。",
        Key.markdownWebPreviewRenderAnyway.rawValue: "仍然渲染",
        Key.markdownWebPreviewOpenNative.rawValue: "打开原生预览",
        Key.markdownWebPreviewOpenSource.rawValue: "打开 Markdown 源码",
        Key.markdownWebPreviewFailedTitle.rawValue: "Web 预览失败",
        Key.markdownWebPreviewAssetsMissing.rawValue: "App bundle 中缺少 Web 预览资源。",
        Key.markdownWebPreviewPayloadEncodeFailed.rawValue: "无法编码预览 payload。",
        Key.markdownWebPreviewRenderCallFailed.rawValue: "渲染调用失败：%@",
        Key.markdownWebPreviewWebViewLoadFailed.rawValue: "WebView 加载失败：%@",
        Key.markdownWebPreviewWebViewProvisionalLoadFailed.rawValue: "WebView 预加载失败：%@",
        Key.markdownWebPreviewUnknownRenderError.rawValue: "未知渲染错误",

        Key.errorConnectionFailed.rawValue: "连接失败：%@",
        Key.errorServerError.rawValue: "服务器错误：%@",
        Key.errorInvalidResponse.rawValue: "服务器返回了无效的响应",
        Key.errorUnauthorized.rawValue: "未授权，请检查认证信息",
        Key.errorSessionNotFound.rawValue: "会话不存在",
        Key.errorFileNotFound.rawValue: "文件不存在：%@",
        Key.errorOperationFailed.rawValue: "操作失败：%@",
        Key.errorUnknown.rawValue: "未知错误：%@",
        Key.errorInvalidBaseURL.rawValue: "无效的 URL",
        Key.helpLanHttp.rawValue: "LAN: HTTP 允许，但建议仅在可信局域网内使用。HTTP 不安全。",
        Key.helpWanHttp.rawValue: "WAN: 需要 HTTPS（HTTP 会被阻止）。HTTP 不安全。",
        Key.helpTailscaleHttp.rawValue: "Tailscale 不要求 HTTPS；其他广域网地址仍需使用 HTTPS。",

        Key.activityRetrying.rawValue: "重试中",
        Key.activityThinking.rawValue: "思考中",
        Key.activityDelegating.rawValue: "委派任务",
        Key.activityPlanning.rawValue: "规划中",
        Key.activityGatheringContext.rawValue: "收集上下文",
        Key.activitySearchingCodebase.rawValue: "搜索代码库",
        Key.activitySearchingWeb.rawValue: "搜索网络",
        Key.activityMakingEdits.rawValue: "修改代码",
        Key.activityRunningCommands.rawValue: "执行命令",
        Key.activityGatheringThoughts.rawValue: "整理思路",

        Key.configureTitle.rawValue: "模型与智能体",
        Key.configureModel.rawValue: "模型",
        Key.configureAgent.rawValue: "智能体",
        Key.configureNoAgents.rawValue: "暂无可用智能体",
        Key.configureModelSearchPlaceholder.rawValue: "搜索模型",
        Key.configureModelNoMatches.rawValue: "没有匹配的模型",
        Key.configureModelEmptyShortlist.rawValue: "请到设置 → 模型 添加。",
        Key.configureModelEditShortlist.rawValue: "到设置里添加、删除或排序",

        Key.todoPanelTitle.rawValue: "任务",
        Key.todoPanelCompleted.rawValue: "%d/%d 已完成",
        Key.todoPanelEmpty.rawValue: "暂无任务",
        Key.todoUpdatedBadge.rawValue: "任务更新 · %d/%d",
    ]

    nonisolated(unsafe) static var ephemeralLanguageOverride: LanguagePreference?

    static func useEphemeralLanguage(_ preference: LanguagePreference) {
        ephemeralLanguageOverride = preference
    }

    nonisolated static var languagePreference: LanguagePreference {
        get {
            if let ephemeralLanguageOverride { return ephemeralLanguageOverride }
            let raw = UserDefaults.standard.string(forKey: languagePreferenceUserDefaultsKey)
            return raw.flatMap(LanguagePreference.init(rawValue:)) ?? .system
        }
        set {
            if ephemeralLanguageOverride != nil {
                ephemeralLanguageOverride = newValue
                return
            }
            UserDefaults.standard.set(newValue.rawValue, forKey: languagePreferenceUserDefaultsKey)
        }
    }

    nonisolated static var currentLocale: Locale {
        if let identifier = languagePreference.localeIdentifier {
            return Locale(identifier: identifier)
        }
        return Locale.current
    }

    nonisolated private static var languageIsChinese: Bool {
        switch languagePreference {
        case .system:
            let preferred = Locale.preferredLanguages.first ?? "en"
            return preferred.lowercased().hasPrefix("zh")
        case .en:
            return false
        case .zh:
            return true
        }
    }

    static var dictionaries: ([String: String], [String: String]) {
        return (en, languageIsChinese ? zh : en)
    }

    nonisolated static func t(_ key: Key) -> String {
        let translations = languageIsChinese ? zh : en
        return translations[key.rawValue] ?? en[key.rawValue] ?? key.rawValue
    }

    nonisolated static func t(_ key: Key, _ arguments: CVarArg...) -> String {
        let template = t(key)
        guard !arguments.isEmpty else { return template }
        return String(format: template, locale: currentLocale, arguments: arguments)
    }

    /// How many files a turn changed.
    static func patchFilesChanged(_ count: Int) -> String {
        let key: Key = count == 1 ? .patchFilesChangedOne : .patchFilesChangedMany
        return formatCount(key: key, count: count)
    }

    private static func formatCount(key: Key, count: Int) -> String {
        t(key).replacingOccurrences(of: "%d", with: count.formatted(.number.locale(currentLocale)))
    }

    static func toolOpenFileLabel(path: String) -> String {
        return t(.toolOpenInFileTree, path)
    }

    static func helpForURLScheme(isLocal: Bool, isTailscale: Bool) -> String {
        if isTailscale { return t(.helpTailscaleHttp) }
        return isLocal ? t(.helpLanHttp) : t(.helpWanHttp)
    }

    static func errorMessage(_ key: Key, _ detail: String) -> String {
        return t(key, detail)
    }

    static var missingEnglishKeys: [String] {
        Key.allCases.map(\.rawValue).filter { en[$0] == nil }
    }

    static var missingChineseKeys: [String] {
        Key.allCases.map(\.rawValue).filter { zh[$0] == nil }
    }
}
