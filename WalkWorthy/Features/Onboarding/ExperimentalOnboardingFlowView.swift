import StoreKit
import SwiftUI
import SwiftData

struct OnboardingBootstrapResult {
    let package: DailyJourneyPackageRecord
    let inferredGrowthFocus: String
}

struct PreparedOnboardingJourney {
    let seed: JourneySeedPayload
    let package: DailyJourneyPackage
}

struct ExperimentalOnboardingFlowView: View {
    enum Step: Int, CaseIterable {
        case intro
        case name
        case bannerName
        case bannerTruth
        case bannerChange
        case method
        case grounding
        case prayerIntent
        case generating
        case tendReflection
        case tendPrayer
        case tendNextStep
        case creationSprout
        case firstTendCelebration
        case backgroundSelection
        case review
        case reminder
        case widget
    }

    let onPrepare: (String, String) async -> PreparedOnboardingJourney?
    let onGenerate: (String, String) async -> OnboardingBootstrapResult?
    let onCommitPrepared: (PreparedOnboardingJourney, String, String) async -> OnboardingBootstrapResult?
    let onComplete: (OnboardingProfile) -> Void
    let onRequirePaywall: (PaywallTriggerReason) -> Void
    let experimentConfig: OnboardingExperimentConfig

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.requestReview) private var requestReview
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var notificationService: NotificationService

    @Query(sort: \ReminderSchedule.sortOrder) private var reminderRows: [ReminderSchedule]

    enum Field: Hashable {
        case name, prayer, action
    }
    @FocusState private var focusedField: Field?

    @State private var step: Step = .intro

    @State private var name = ""
    @State private var prayerIntentText = ""
    @State private var inferredGrowthFocus = ""
    @State private var actionStepText = ""
    @State private var generatedPackage: DailyJourneyPackageRecord?

    @AppStorage("homeBackgroundTheme") private var backgroundTheme: HomeBackgroundTheme = .morningGarden

    @State private var reviewActionTaken = false
    @State private var resolvedExperimentConfig: OnboardingExperimentConfig = .default
    @State private var celebrationSceneVisible = false
    @State private var celebrationStepSettled = false
    @State private var celebrationWaterDropY: CGFloat = -96
    @State private var celebrationWaterDropOpacity = 0.0
    @State private var celebrationSoilGlow = 0.0
    @State private var celebrationPlantScale = 0.92
    @State private var celebrationTomorrowCueVisible = false
    @State private var generationSequencePhase = 0
    @State private var generationIsReady = false
    @State private var preparedJourney: PreparedOnboardingJourney?
    @State private var preparedJourneyKey = ""
    @State private var preparedJourneyTask: Task<PreparedOnboardingJourney?, Never>?

    private let analytics: AnalyticsTracking = AnalyticsServiceFactory.makeDefault()

    private let reminderOptions = ["Morning", "Afternoon", "Evening"]
    private let prayerIntentSuggestions = [
        "Trusting God with my anxiety",
        "Growing consistency in prayer",
        "Healing in a relationship",
        "Wisdom for a hard decision"
    ]

    private var firstStepSuggestions: [String] {
        Array((generatedPackage?.suggestedSteps ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(4))
    }

    private var firstJourneyThemeSuffix: String {
        guard let entryID = generatedPackage?.linkedEntryID else { return "basic" }
        let descriptor = FetchDescriptor<PrayerEntry>(
            predicate: #Predicate<PrayerEntry> { $0.id == entryID }
        )
        guard let entry = try? modelContext.fetch(descriptor).first,
              let journey = entry.journey else {
            return "basic"
        }
        return journey.themeKey.rawValue
    }

    private var firstStagePlantImageName: String {
        "growth_stage_1_seed_\(firstJourneyThemeSuffix)"
    }

    private var celebrationBackgroundAssetName: String {
        backgroundTheme.assetName ?? HomeBackgroundTheme.morningGarden.assetName ?? "home_plant_background_morning_garden"
    }

    private var celebrationStepText: String {
        actionStepText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var prayerPreviewText: String {
        let trimmed = prayerIntentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return copy("generating_prayer_fallback", fallback: "Your prayer") }
        if trimmed.count <= 72 { return trimmed }
        return String(trimmed.prefix(69)) + "..."
    }

    private var supportsWidgetsOnCurrentDevice: Bool {
        UIDevice.current.userInterfaceIdiom != .pad
    }

    // MARK: - Body
    var body: some View {
        GeometryReader { proxy in
            let safeArea = proxy.safeAreaInsets
            let availableHeight = proxy.size.height - safeArea.top - safeArea.bottom
            let topHalfHeight = availableHeight * topHalfRatio(for: step, availableHeight: availableHeight)
            let keyboardActive = focusedField != nil
            let keyboardCompactedTopHeight = (isTextEntryStep && keyboardActive) ? topHalfHeight * 0.66 : topHalfHeight
            let horizontalInset = max(16, min(22, proxy.size.width * 0.05))
            
            ZStack {
                backgroundColor
                    .ignoresSafeArea()
                    .onTapGesture {
                        focusedField = nil
                    }
                
                if isBannerStep {
                    AmbientBannerBackground(step: step)
                        .ignoresSafeArea()
                        .transition(.opacity)
                }
                
                VStack(spacing: 0) {
                    // Top Progress Bar
                    if step != .intro && step != .generating && step != .creationSprout && step != .widget {
                        progressBar
                            .padding(.horizontal, horizontalInset)
                            .padding(.top, 16)
                    } else {
                        Spacer().frame(height: 24) // Placeholder for alignment
                    }
                    
                    // Top Half: Visuals
                    topVisualHalf(metrics: proxy, height: keyboardCompactedTopHeight)
                        .frame(height: keyboardCompactedTopHeight)
                        .frame(maxWidth: .infinity)
                    
                    // Bottom Half: Interactive Controls
                    bottomInteractiveHalf(metrics: proxy, availableHeight: availableHeight)
                        .frame(maxHeight: .infinity)
                        .padding(.horizontal, horizontalInset)
                        .padding(.top, 12)
                }
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: step)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if step != .creationSprout && step != .generating {
                    ctaRow
                        .padding(.horizontal, horizontalInset)
                        .padding(.top, 8)
                        .padding(.bottom, keyboardActive ? 8 : max(16, safeArea.bottom))
                        .background(Color.clear)
                }
            }
        }
        .onChange(of: step) { _, newStep in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                switch newStep {
                case .name: focusedField = .name
                case .prayerIntent: focusedField = .prayer
                case .tendNextStep: focusedField = .action
                default: focusedField = nil
                }
            }

            if newStep == .reminder && reminderRows.isEmpty {
                let defaultReminder = ReminderSchedule(hour: 8, minute: 0, isEnabled: true, sortOrder: 0)
                modelContext.insert(defaultReminder)
                try? modelContext.save()
            }

            if newStep == .creationSprout {
                analytics.track(.onboardingWowSeen, properties: [:])
            }

            if newStep == .review {
                analytics.track(.reviewPromptShown, properties: ["source": "onboarding_step"])
            }
        }
        .onAppear {
            resolvedExperimentConfig = experimentConfig
            ensureCurrentStepIsValidForSequence()
        }
        .onChange(of: experimentConfig) { _, newConfig in
            guard step == .intro else { return }
            resolvedExperimentConfig = newConfig
            ensureCurrentStepIsValidForSequence()
        }
    }
    
    // MARK: - Layout Areas
    
    private var progressBar: some View {
        let trackedSteps = onboardingFlowSequence.filter { ![.intro, .generating, .creationSprout, .widget].contains($0) }
        let currentIndex = max(0, trackedSteps.firstIndex(of: step) ?? 0)
        let totalSteps = max(1, trackedSteps.count)
        
        return HStack(spacing: 6) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Capsule()
                    .fill(index <= currentIndex ? WWColor.growGreen : WWColor.growGreen.opacity(0.2))
                    .frame(height: 4)
                    .frame(maxWidth: .infinity)
            }
        }
    }
    
    @ViewBuilder
    private func topVisualHalf(metrics: GeometryProxy, height: CGFloat) -> some View {
        VStack {
            Spacer()
            switch step {
            case .intro:
                OnboardingIntroLoopView(size: min(height * 0.7, 220))
            case .generating:
                VStack(spacing: 30) {
                    onboardingAnticipationVisual(height: height)
                    generatingContent
                }
            case .name, .prayerIntent:
                Image("TendMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: min(height * 0.48, 116))
                    .opacity(0.8)
            case .tendReflection, .tendPrayer, .tendNextStep:
                tendRitualThreadVisual(height: height)
            case .method:
                 Image("TendMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: min(height * 0.48, 116))
            case .grounding:
                 Image("TendMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: min(height * 0.48, 116))
            case .reminder:
                EmptyView()
            case .widget:
                Image("OnboardingWidgetScreenshot")
                    .resizable()
                    .scaledToFit()
                    .frame(height: min(height * 0.98, 560))
            case .creationSprout:
                ZStack(alignment: .bottom) {
                    // Halo (Evolution style)
                    if sproutGlow > 0 {
                        Circle()
                            .fill(WWColor.morningGold.opacity(0.4))
                            .frame(width: 250, height: 250)
                            .blur(radius: 40)
                            .scaleEffect(haloScale)
                            .offset(y: -40)
                    }

                    // Soil
                    Image("generic_soil")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 160)
                        .opacity(soilOpacity)
                        .colorMultiply(isSilhouette ? .black : Color(white: 1.0 - soilDarkness * 0.4))
                        .brightness(isSilhouette ? -1 : 0)
                        .zIndex(0)

                    // Seed
                    if !revealPlant {
                        Image("generic_seed")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 50)
                            .offset(y: seedOffset)
                            .opacity(seedOpacity)
                            .colorMultiply(isSilhouette ? .black : .white)
                            .brightness(isSilhouette ? -1 : 0)
                            .zIndex(1)
                    } else {
                        // Evolved Plant Reveal
                        Image(firstStagePlantImageName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120)
                            .offset(y: -20)
                            .opacity(plantOpacity)
                            .colorMultiply(isSilhouette ? .black : .white)
                            .brightness(isSilhouette ? -1 : 0)
                            .shadow(color: isSilhouette ? .clear : .black.opacity(0.3), radius: 10, y: 5)
                            .scaleEffect(isSilhouette ? 0.9 : 1.1)
                            .zIndex(2)
                    }
                }
                .frame(height: 180)
            case .firstTendCelebration:
                celebrationGardenArrivalVisual(metrics: metrics, height: height)
            case .backgroundSelection:
                ZStack(alignment: .bottom) {
                    if let assetName = backgroundTheme.assetName {
                        Image(assetName)
                            .resizable()
                            .scaledToFill()
                            .frame(width: metrics.size.width - 40, height: height)
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                            .overlay(
                                LinearGradient(
                                    colors: [.clear, WWColor.nearBlack.opacity(0.4)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(solidThemeBackgroundColor)
                            .frame(width: metrics.size.width - 40, height: height)
                    }

                    Image(firstStagePlantImageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120)
                        .offset(y: -20)
                        .shadow(color: .black.opacity(0.4), radius: 15, y: 10)
                }
            case .review, .bannerName, .bannerTruth, .bannerChange:
                EmptyView() // Text-heavy screens might use the full space or just bottom
            }
            Spacer()
        }
    }
    
    @ViewBuilder
    private func bottomInteractiveHalf(metrics: GeometryProxy, availableHeight: CGFloat) -> some View {
        let contentScale = bottomContentScale(for: step, availableHeight: availableHeight)

        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                switch step {
                case .intro:
                    introContent
                case .name:
                    nameContent
                case .bannerName:
                    bannerNameContent
                case .bannerTruth:
                    bannerTruthContent
                case .bannerChange:
                    bannerChangeContent
                case .prayerIntent:
                    prayerIntentContent
                case .generating:
                    EmptyView()
                case .tendReflection:
                    tendReflectionContent
                case .tendPrayer:
                    tendPrayerContent
                case .tendNextStep:
                    tendNextStepContent
                case .method:
                    methodContent
                case .grounding:
                    groundingContent
                case .firstTendCelebration:
                    firstTendCelebrationContent
                case .review:
                    reviewContent
                case .reminder:
                    reminderContent
                case .widget:
                    widgetContent
                case .creationSprout:
                    creationSproutContent
                case .backgroundSelection:
                    backgroundSelectionContent
                }
            }
            .frame(maxWidth: .infinity, alignment: step == .intro || isBannerStep ? .center : .leading)
            .scaleEffect(contentScale, anchor: .top)
            .frame(maxWidth: .infinity, alignment: .top)
            .padding(.bottom, ctaClearanceInset)
            .contentShape(Rectangle())
            .onTapGesture {
                focusedField = nil
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxHeight: .infinity, alignment: .top)
    }
    
    // MARK: - Step Contents (Bottom Half)
    
    private var introContent: some View {
        VStack(spacing: 12) {
            Text(copy("intro_title", fallback: "Welcome to Tend"))
                .font(WWTypography.display(36))
                .foregroundStyle(WWColor.nearBlack)
                .multilineTextAlignment(.center)
            
            Text(copy("intro_subtitle", fallback: "pray. act. grow."))
                .font(WWTypography.heading(24))
                .foregroundStyle(WWColor.growGreen)
            
            Text(copy("intro_tagline", fallback: "turn your prayers into small\nsteps of real growth"))
                .font(WWTypography.heading(18).italic())
                .foregroundStyle(WWColor.muted)
                .multilineTextAlignment(.center)
                .padding(.top, 16)
        }
    }
    
    private var nameContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(copy("name_title", fallback: "What should Tend call you?"))
                .font(WWTypography.display(32))
                .foregroundStyle(WWColor.nearBlack)
            
            TextField(copy("name_placeholder", fallback: "Enter your name"), text: $name)
                .focused($focusedField, equals: .name)
                .font(WWTypography.heading(22))
                .foregroundStyle(WWColor.nearBlack)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(WWColor.white)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(WWColor.growGreen.opacity(name.isEmpty ? 0 : 1), lineWidth: 1))
                .shadow(color: WWColor.nearBlack.opacity(0.04), radius: 10, x: 0, y: 4)
        }
    }
    
    private var prayerIntentContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(copy("prayer_intent_title", fallback: "Bring what’s real."))
                .font(WWTypography.display(34))
                .foregroundStyle(WWColor.nearBlack)
                .fixedSize(horizontal: false, vertical: true)

            Text(copy("prayer_intent_helper", fallback: "What do you want to pray about right now?"))
                .font(WWTypography.heading(18))
                .foregroundStyle(WWColor.muted)
                .fixedSize(horizontal: false, vertical: true)

            TextField(copy("prayer_intent_placeholder", fallback: "My prayer is..."), text: newlineDismissBinding(for: $prayerIntentText), axis: .vertical)
                .focused($focusedField, equals: .prayer)
                .submitLabel(.done)
                .onSubmit { focusedField = nil }
                .font(WWTypography.heading(18))
                .foregroundStyle(WWColor.nearBlack)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(minHeight: 130, alignment: .top)
                .background(WWColor.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(WWColor.growGreen.opacity(prayerIntentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0 : 1), lineWidth: 1)
                )
                .shadow(color: WWColor.nearBlack.opacity(0.04), radius: 10, x: 0, y: 4)

            VStack(alignment: .leading, spacing: 10) {
                Text(copy("prayer_intent_suggestions_title", fallback: "Need a starter?"))
                    .font(WWTypography.caption(16).weight(.semibold))
                    .foregroundStyle(WWColor.muted)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(prayerIntentSuggestions, id: \.self) { suggestion in
                        Button {
                            prayerIntentText = copy(suggestionKey(for: suggestion), fallback: suggestion)
                        } label: {
                            Text(copy(suggestionKey(for: suggestion), fallback: suggestion))
                                .font(WWTypography.heading(18))
                                .foregroundStyle(WWColor.nearBlack)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .frame(minHeight: 84, alignment: .topLeading)
                                .background(WWColor.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(
                                            prayerIntentText.trimmingCharacters(in: .whitespacesAndNewlines) == copy(suggestionKey(for: suggestion), fallback: suggestion)
                                                ? WWColor.growGreen.opacity(0.8)
                                                : WWColor.nearBlack.opacity(0.08),
                                            lineWidth: 1
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
    
    private var generatingContent: some View {
        VStack(spacing: 10) {
            Text(
                generationIsReady
                    ? copy("generating_ready_title", fallback: "Your journey is ready.")
                    : copy("generating_title", fallback: "Shaping your journey...")
            )
                .font(WWTypography.display(30))
                .foregroundStyle(WWColor.nearBlack)
                .contentTransition(.opacity)
        }
        .frame(maxWidth: .infinity)
    }

    private var tendReflectionContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            ritualStageLabel(copy("tend_ritual_stage_scripture", fallback: "Scripture"))

            Text(copy("tend_reflection_title", fallback: "Begin with Scripture."))
                .font(WWTypography.display(36))
                .foregroundStyle(WWColor.nearBlack)
                .fixedSize(horizontal: false, vertical: true)

            ritualSurface {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(generatedPackage?.scriptureReference ?? copy("tend_scripture_label", fallback: "Scripture"))
                            .font(WWTypography.caption(12).weight(.bold))
                            .foregroundStyle(WWColor.growGreen)
                            .tracking(1.0)

                        Text(generatedPackage?.scriptureParaphrase ?? "...")
                            .font(WWTypography.heading(22))
                            .foregroundStyle(WWColor.nearBlack)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                    }

                    Rectangle()
                        .fill(WWColor.growGreen.opacity(0.28))
                        .frame(width: 44, height: 2)

                    Text(generatedPackage?.reflectionThought ?? "...")
                        .font(WWTypography.body(18))
                        .foregroundStyle(WWColor.muted)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
            }
        }
    }

    private var tendPrayerContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            ritualStageLabel(copy("tend_ritual_stage_prayer", fallback: "Prayer"))

            Text(copy("tend_prayer_title", fallback: "Pray for today."))
                .font(WWTypography.display(36))
                .foregroundStyle(WWColor.nearBlack)
                .fixedSize(horizontal: false, vertical: true)

            ritualSurface {
                Text(generatedPackage?.prayer ?? "...")
                    .font(WWTypography.body(20))
                    .foregroundStyle(WWColor.nearBlack)
                    .italic()
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var tendNextStepContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            ritualStageLabel(copy("tend_ritual_stage_step", fallback: "Step"))

            Text(copy("tend_step_title", fallback: "Today I will..."))
                .font(WWTypography.display(38))
                .foregroundStyle(WWColor.nearBlack)
            
            Text(copy("tend_step_question_fallback", fallback: "What is one thing you can do to partner with this prayer today?"))
                .font(WWTypography.heading(19))
                .foregroundStyle(WWColor.muted)
                .fixedSize(horizontal: false, vertical: true)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(copy("tend_step_commitment_label", fallback: "Today I will"))
                    .font(WWTypography.caption(13).weight(.bold))
                    .foregroundStyle(WWColor.growGreen)
                    .tracking(1.2)

                TextField(copy("tend_step_placeholder", fallback: "write one lived response..."), text: newlineDismissBinding(for: $actionStepText), axis: .vertical)
                    .focused($focusedField, equals: .action)
                    .submitLabel(.done)
                    .onSubmit { focusedField = nil }
                    .font(WWTypography.heading(22))
                    .foregroundStyle(WWColor.nearBlack)
                    .frame(minHeight: 92, alignment: .top)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(WWColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(WWColor.growGreen.opacity(actionStepText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.12 : 0.75), lineWidth: 1)
            )

            if !firstStepSuggestions.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(copy("tend_step_suggestions_title", fallback: "Or start here"))
                        .font(WWTypography.caption(16).weight(.semibold))
                        .foregroundStyle(WWColor.muted)

                    VStack(spacing: 10) {
                        ForEach(firstStepSuggestions, id: \.self) { suggestion in
                            let selected = actionStepText.trimmingCharacters(in: .whitespacesAndNewlines) == suggestion
                            Button {
                                actionStepText = suggestion
                                focusedField = nil
                            } label: {
                                HStack(alignment: .center, spacing: 12) {
                                    Text(suggestion)
                                        .font(WWTypography.heading(17))
                                        .foregroundStyle(WWColor.nearBlack)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)

                                    Circle()
                                        .fill(selected ? WWColor.growGreen : WWColor.muted.opacity(0.20))
                                        .frame(width: 7, height: 7)
                                }
                                .padding(.horizontal, 18)
                                .padding(.vertical, 15)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(selected ? WWColor.growGreen.opacity(0.12) : WWColor.nearBlack.opacity(0.04))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func ritualStageLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(WWTypography.caption(13).weight(.bold))
            .foregroundStyle(WWColor.growGreen)
            .tracking(2.4)
    }

    private func ritualSurface<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 22)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [
                        WWColor.surface.opacity(0.92),
                        WWColor.surface.opacity(0.58)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var firstTendCelebrationContent: some View {
        VStack(alignment: .center, spacing: 6) {
            Text(copy("celebration_title", fallback: "Day 1"))
                .font(WWTypography.display(52))
                .foregroundStyle(WWColor.nearBlack)
                .multilineTextAlignment(.center)

            Text(copy("celebration_cta_hint", fallback: "Keep coming back to see your plant grow."))
                .font(WWTypography.heading(18))
                .foregroundStyle(WWColor.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private func celebrationGardenArrivalVisual(metrics: GeometryProxy, height: CGFloat) -> some View {
        let sceneWidth = metrics.size.width - 40
        let sceneHeight = max(300, min(height - 10, 430))

        return ZStack(alignment: .bottom) {
            Image(celebrationBackgroundAssetName)
                .resizable()
                .scaledToFill()
                .frame(width: sceneWidth, height: sceneHeight)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(
                    LinearGradient(
                        colors: [
                            WWColor.nearBlack.opacity(0.04),
                            WWColor.nearBlack.opacity(0.10),
                            WWColor.nearBlack.opacity(0.18)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                )

            VStack {
                HStack(spacing: 7) {
                    celebrationStatusBadge(
                        systemName: "sun.max.fill",
                        text: copy("celebration_streak_value", fallback: "1 day")
                    )
                    celebrationStatusBadge(
                        systemName: "drop.fill",
                        text: copy("celebration_water_value", fallback: "Hydrated")
                    )
                }
                .padding(.top, 16)
                .padding(.trailing, 16)
                .opacity(celebrationSceneVisible ? 1 : 0)

                Spacer()
            }
            .frame(width: sceneWidth, height: sceneHeight, alignment: .topTrailing)

            if !celebrationStepText.isEmpty {
                VStack(spacing: 8) {
                    Capsule()
                        .fill(WWColor.growGreen.opacity(0.42))
                        .frame(width: 2, height: 34)
                        .opacity(celebrationStepSettled ? 1 : 0)

                    plantedStepTag
                        .frame(maxWidth: sceneWidth - 88)
                }
                .offset(y: celebrationStepSettled ? -82 : -42)
                .opacity(celebrationSceneVisible ? 1 : 0)
                .scaleEffect(celebrationStepSettled ? 0.94 : 1.0)
            }

            futureGrowthCue
                .offset(x: sceneWidth * 0.16, y: -178)
                .opacity(celebrationTomorrowCueVisible ? 1 : 0)
                .scaleEffect(celebrationTomorrowCueVisible ? 1.0 : 0.78)

            Circle()
                .fill(WWColor.morningGold.opacity(0.50 * celebrationSoilGlow))
                .frame(width: 170, height: 90)
                .blur(radius: 28)
                .offset(y: -28)

            Image(systemName: "drop.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(WWColor.growGreen)
                .shadow(color: WWColor.growGreen.opacity(0.5), radius: 10, y: 6)
                .offset(y: celebrationWaterDropY)
                .opacity(celebrationWaterDropOpacity)

            Image(firstStagePlantImageName)
                .resizable()
                .scaledToFit()
                .frame(width: min(sceneHeight * 0.34, 142))
                .offset(y: -30)
                .scaleEffect(celebrationPlantScale)
                .shadow(color: WWColor.growGreen.opacity(0.36 * celebrationSoilGlow), radius: 22, y: 8)
        }
        .frame(width: sceneWidth, height: sceneHeight)
        .opacity(celebrationSceneVisible ? 1 : 0.92)
        .onAppear {
            runCelebrationArrivalSequence()
        }
        .onDisappear {
            resetCelebrationArrivalSequence()
        }
    }

    private var plantedStepTag: some View {
        HStack(spacing: 10) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(WWColor.growGreen)

            Text(celebrationStepText)
                .font(WWTypography.heading(15))
                .foregroundStyle(WWColor.nearBlack)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 10)
        .background(WWColor.surface.opacity(0.86))
        .clipShape(Capsule())
        .shadow(color: WWColor.nearBlack.opacity(0.10), radius: 12, y: 6)
    }

    private var futureGrowthCue: some View {
        ZStack {
            Circle()
                .fill(WWColor.growGreen.opacity(0.18))
                .frame(width: 48, height: 34)
                .blur(radius: 12)

            VStack(spacing: -2) {
                HStack(spacing: -1) {
                    Capsule()
                        .fill(WWColor.growGreen.opacity(0.58))
                        .frame(width: 9, height: 5)
                        .rotationEffect(.degrees(-32))
                    Capsule()
                        .fill(WWColor.growGreen.opacity(0.58))
                        .frame(width: 9, height: 5)
                        .rotationEffect(.degrees(32))
                }
                Capsule()
                    .fill(WWColor.growGreen.opacity(0.48))
                    .frame(width: 2, height: 12)
            }
        }
        .accessibilityHidden(true)
    }

    private func celebrationStatusBadge(systemName: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .bold))
            Text(text)
                .font(WWTypography.caption(10).weight(.bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(WWColor.nearBlack.opacity(0.26))
        .clipShape(Capsule())
    }

    private func resetCelebrationArrivalSequence() {
        celebrationSceneVisible = false
        celebrationStepSettled = false
        celebrationWaterDropY = -96
        celebrationWaterDropOpacity = 0.0
        celebrationSoilGlow = 0.0
        celebrationPlantScale = 0.92
        celebrationTomorrowCueVisible = false
    }

    private func runCelebrationArrivalSequence() {
        resetCelebrationArrivalSequence()

        guard !reduceMotion else {
            celebrationSceneVisible = true
            celebrationStepSettled = true
            celebrationWaterDropY = -18
            celebrationWaterDropOpacity = 0.0
            celebrationSoilGlow = 1.0
            celebrationPlantScale = 1.0
            celebrationTomorrowCueVisible = true
            return
        }

        withAnimation(.easeOut(duration: 0.35)) {
            celebrationSceneVisible = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
            withAnimation(.spring(response: 0.72, dampingFraction: 0.82)) {
                celebrationStepSettled = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.72) {
            celebrationWaterDropOpacity = 1.0
            withAnimation(.easeIn(duration: 0.56)) {
                celebrationWaterDropY = -18
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.24) {
            withAnimation(.easeOut(duration: 0.18)) {
                celebrationWaterDropOpacity = 0.0
            }
            withAnimation(.spring(response: 0.62, dampingFraction: 0.58)) {
                celebrationSoilGlow = 1.0
                celebrationPlantScale = 1.05
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.72) {
            withAnimation(.easeOut(duration: 0.42)) {
                celebrationPlantScale = 1.0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.94) {
            withAnimation(.spring(response: 0.72, dampingFraction: 0.82)) {
                celebrationTomorrowCueVisible = true
            }
        }
    }
    
    private var bannerNameContent: some View {
        VStack(spacing: 16) {
            Text(applyFirstNamePlaceholder(copy("banner_name_title", fallback: "\(firstNameDisplay), your prayers matter.")))
                .font(WWTypography.display(32))
                .foregroundStyle(WWColor.nearBlack)
                .multilineTextAlignment(.center)

            Text(copy("banner_name_subtitle", fallback: "so does your next step."))
                .font(WWTypography.display(32))
                .foregroundStyle(WWColor.growGreen)
                .multilineTextAlignment(.center)
        }
    }
    
    private var bannerTruthContent: some View {
        VStack(spacing: 20) {
            Text(copy("banner_truth_title", fallback: "What you pray can shape\nhow you live."))
                .font(WWTypography.display(32))
                .foregroundStyle(WWColor.nearBlack)
                .multilineTextAlignment(.center)

            Text(copy("banner_truth_subtitle", fallback: "Tend helps you turn\nyour prayers into your habits,\ndecisions, and daily life."))
                .font(WWTypography.heading(22))
                .foregroundStyle(WWColor.nearBlack)
                .multilineTextAlignment(.center)
        }
    }
    
    private var bannerChangeContent: some View {
        VStack(spacing: 20) {
            Text(copy("banner_change_title", fallback: "What if prayer became\nthe start of real change?"))
                .font(WWTypography.display(36))
                .foregroundStyle(WWColor.nearBlack)
                .multilineTextAlignment(.center)
        }
    }
    
    private var methodContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(copy("method_title", fallback: "Here’s how Tend works"))
                .font(WWTypography.display(32))
                .foregroundStyle(WWColor.nearBlack)
                .padding(.bottom, 8)
            
            VStack(alignment: .leading, spacing: 14) {
                featureBullet(
                    lead: copy("method_bullet_pray_lead", fallback: "Pray"),
                    text: copy("method_bullet_pray_text", fallback: "about what matters")
                )
                featureBullet(
                    lead: copy("method_bullet_reflect_lead", fallback: "Reflect"),
                    text: copy("method_bullet_reflect_text", fallback: "with Scripture")
                )
                featureBullet(
                    lead: copy("method_bullet_choose_lead", fallback: "Choose"),
                    text: copy("method_bullet_choose_text", fallback: "one small step")
                )
                featureBullet(
                    lead: copy("method_bullet_grow_lead", fallback: "Grow"),
                    text: copy("method_bullet_grow_text", fallback: "through daily faithfulness")
                )
            }
        }
    }
    
    private var groundingContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(copy("grounding_title", fallback: "Faith grows when it’s lived."))
                .font(WWTypography.heading(28).italic())
                .foregroundStyle(WWColor.nearBlack)
            
            WWCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text(copy("grounding_body", fallback: "What you pray can shape how you live, and small faithful steps can bear real fruit over time."))
                    .font(WWTypography.heading(18))
                    .foregroundStyle(WWColor.nearBlack)
                }
            }
        }
    }
    
    private var reminderContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(copy("reminder_title", fallback: "Return to what matters."))
                .font(WWTypography.display(32))
                .foregroundStyle(WWColor.nearBlack)
            
            Text(copy("reminder_subtitle", fallback: "Choose a gentle reminder for tomorrow’s Tend."))
                .font(WWTypography.heading(18))
                .foregroundStyle(WWColor.muted)

            List {
                ForEach(reminderRows) { reminder in
                    HStack {
                        DatePicker("", selection: Binding(
                            get: { Calendar.current.date(from: DateComponents(hour: reminder.hour, minute: reminder.minute)) ?? .now },
                            set: { value in
                                let c = Calendar.current.dateComponents([.hour, .minute], from: value)
                                reminder.hour = c.hour ?? 8
                                reminder.minute = c.minute ?? 0
                                try? modelContext.save()
                            }
                        ), displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { reminder.isEnabled },
                            set: { value in
                                reminder.isEnabled = value
                                try? modelContext.save()
                            }
                        ))
                        .labelsHidden()
                        .tint(WWColor.growGreen)
                    }
                    .listRowBackground(WWColor.surface)
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        modelContext.delete(reminderRows[index])
                    }
                    try? modelContext.save()
                }

                Button {
                    let newReminder = ReminderSchedule(hour: 8, minute: 0, isEnabled: true, sortOrder: reminderRows.count)
                    modelContext.insert(newReminder)
                    try? modelContext.save()
                } label: {
                    Label(copy("reminder_add_button", fallback: "Add Reminder"), systemImage: "plus.circle.fill")
                        .foregroundStyle(WWColor.growGreen)
                        .font(WWTypography.heading(16))
                }
                .listRowBackground(WWColor.surface)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(WWColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(WWColor.growGreen.opacity(0.10), lineWidth: 1)
            )
            .shadow(color: WWColor.growGreen.opacity(0.08), radius: 18, x: 0, y: 10)
            .frame(height: 180)
        }
    }
    
    private var widgetContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(copy("widget_title", fallback: "Keep your journey close."))
                .font(WWTypography.display(36))
                .foregroundStyle(WWColor.nearBlack)
            
            Text(copy("widget_subtitle", fallback: "See your current prayer, verse, and next step right from your home screen."))
                .font(WWTypography.heading(20))
                .foregroundStyle(WWColor.nearBlack.opacity(0.8))
        }
    }

    @State private var anticipationGlow = false

    @ViewBuilder
    private func onboardingAnticipationVisual(height: CGFloat) -> some View {
        let fragmentVisible = generationSequencePhase >= 1
        let seedVisible = generationSequencePhase >= 1 || generationIsReady
        let markSize = min(height * 0.34, 78)

        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(WWColor.growGreen.opacity(anticipationGlow ? 0.18 : 0.08))
                    .frame(width: markSize, height: markSize)
                    .blur(radius: anticipationGlow ? 20 : 10)
                    .scaleEffect(anticipationGlow ? 1.18 : 0.88)

                VStack {
                    Image("generic_seed")
                        .resizable()
                        .scaledToFit()
                        .frame(width: min(height * 0.15, 38))
                        .offset(y: generationIsReady ? 38 : (anticipationGlow ? -16 : -6))
                        .opacity(seedVisible ? 1 : 0)
                        .scaleEffect(generationIsReady ? 0.82 : (anticipationGlow ? 1.04 : 0.96))
                        .shadow(color: WWColor.growGreen.opacity(generationIsReady ? 0.12 : 0.28), radius: 10, y: 5)
                }
            }
            .frame(height: markSize + 26)

            Text("“\(prayerPreviewText)”")
                .font(WWTypography.heading(15))
                .foregroundStyle(WWColor.nearBlack)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(WWColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .opacity(generationSequencePhase >= 0 ? 1 : 0)
                .scaleEffect(fragmentVisible ? 0.9 : 1.0)
                .blur(radius: generationIsReady ? 0.45 : (fragmentVisible ? 0.25 : 0))

            HStack(spacing: 16) {
                generationFragmentLabel(copy("generating_fragment_scripture", fallback: "Scripture"), index: 0)
                generationFragmentLabel(copy("generating_fragment_prayer", fallback: "Prayer"), index: 1)
                generationFragmentLabel(copy("generating_fragment_step", fallback: "Today I will"), index: 2)
            }
            .opacity(fragmentVisible ? 1 : 0)
            .offset(y: fragmentVisible ? 0 : 10)
        }
        .onAppear {
            generationSequencePhase = reduceMotion ? 2 : 0
            guard !reduceMotion else {
                anticipationGlow = generationIsReady
                return
            }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                anticipationGlow = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                withAnimation(.easeOut(duration: 0.35)) {
                    generationSequencePhase = 1
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.05) {
                withAnimation(.easeOut(duration: 0.28)) {
                    generationSequencePhase = 2
                }
            }
        }
        .onDisappear {
            anticipationGlow = false
            generationSequencePhase = 0
        }
    }

    private func generationFragmentLabel(_ text: String, index: Int) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(WWColor.growGreen.opacity(0.62))
                .frame(width: 5, height: 5)
            Text(text)
                .font(WWTypography.caption(12).weight(.semibold))
                .foregroundStyle(WWColor.growGreen)
        }
        .opacity(generationSequencePhase >= 1 ? 1 : 0)
        .offset(y: generationSequencePhase >= 1 ? 0 : 8)
    }

    private func tendRitualThreadVisual(height: CGFloat) -> some View {
        VStack(spacing: 14) {
            Image("TendMark")
                .resizable()
                .scaledToFit()
                .frame(width: min(height * 0.34, 72))
                .opacity(0.72)

            HStack(spacing: 9) {
                ritualThreadDot(isActive: step == .tendReflection, isPast: ritualStepIndex >= 0)
                ritualThreadLine(isActive: ritualStepIndex >= 1)
                ritualThreadDot(isActive: step == .tendPrayer, isPast: ritualStepIndex >= 1)
                ritualThreadLine(isActive: ritualStepIndex >= 2)
                ritualThreadDot(isActive: step == .tendNextStep, isPast: ritualStepIndex >= 2)
            }
            .opacity(0.9)
        }
    }

    private var ritualStepIndex: Int {
        switch step {
        case .tendReflection: return 0
        case .tendPrayer: return 1
        case .tendNextStep: return 2
        default: return -1
        }
    }

    private func ritualThreadDot(isActive: Bool, isPast: Bool) -> some View {
        Circle()
            .fill(isPast ? WWColor.growGreen : WWColor.muted.opacity(0.22))
            .frame(width: isActive ? 12 : 8, height: isActive ? 12 : 8)
            .shadow(color: isActive ? WWColor.growGreen.opacity(0.45) : .clear, radius: 8)
    }

    private func ritualThreadLine(isActive: Bool) -> some View {
        Capsule()
            .fill(isActive ? WWColor.growGreen.opacity(0.75) : WWColor.muted.opacity(0.18))
            .frame(width: 34, height: 2)
    }
    
    // Seed Animation States
    @State private var soilOpacity: Double = 0.0
    @State private var seedOffset: CGFloat = -180
    @State private var seedOpacity: Double = 0.0
    @State private var soilDarkness: Double = 0.0
    @State private var plantOpacity: Double = 0.0
    @State private var sproutGlow: Double = 0.0
    @State private var isSilhouette: Bool = false
    @State private var revealPlant: Bool = false
    @State private var haloScale: Double = 0.8
    
    private var creationSproutContent: some View {
        VStack {
            Text(copy("creation_sprout_title", fallback: "See it planted."))
                .font(WWTypography.heading(24))
                .foregroundStyle(WWColor.nearBlack)
                .opacity(soilOpacity > 0 ? 1.0 : 0.0)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
        .onAppear {
            runSeedSequence()
        }
    }
    
    private func runSeedSequence() {
        if reduceMotion {
            soilOpacity = 1.0
            seedOffset = -30
            seedOpacity = 0.0
            soilDarkness = 0.0
            plantOpacity = 1.0
            sproutGlow = 0.0
            isSilhouette = false
            revealPlant = true
            haloScale = 1.0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                step = .firstTendCelebration
            }
            return
        }

        // Reset so revisiting this step always replays cleanly.
        soilOpacity = 0.0
        seedOffset = -180
        seedOpacity = 0.0
        soilDarkness = 0.0
        plantOpacity = 0.0
        sproutGlow = 0.0
        isSilhouette = false
        revealPlant = false
        haloScale = 0.8

        // 1. Soil appears
        withAnimation(.easeOut(duration: 0.6)) {
            soilOpacity = 1.0
            seedOffset = -180 // reset seed high up
        }
        
        // 2. Seed drops
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                seedOpacity = 1.0
                seedOffset = -30 // drops into soil
            }
        }
        
        // 3. Darken into Silhouette & Glow
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeInOut(duration: 0.6)) {
                isSilhouette = true
                soilDarkness = 1.0
                sproutGlow = 1.0
            }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                haloScale = 1.2
            }
        }
        
        // 4. Swap seed shadow for plant shadow
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            withAnimation(.easeIn(duration: 0.2)) {
                revealPlant = true
                plantOpacity = 1.0
            }
        }
        
        // 5. Bright Reveal!
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.4) {
            withAnimation(.easeOut(duration: 0.8)) {
                isSilhouette = false
            }
        }
        
        // 6. Advance
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.5) {
            withAnimation { step = .firstTendCelebration }
        }
    }
    
    private var backgroundSelectionContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(copy("background_selection_title", fallback: "Set your scene."))
                .font(WWTypography.display(36))
                .foregroundStyle(WWColor.nearBlack)
            
            Text(copy("background_selection_subtitle", fallback: "Choose where your journey grows."))
                .font(WWTypography.heading(20))
                .foregroundStyle(WWColor.muted)
                
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(HomeBackgroundTheme.allCases) { theme in
                        Button {
                            withAnimation { backgroundTheme = theme }
                        } label: {
                            VStack(spacing: 8) {
                                if let assetName = theme.assetName {
                                    Image(assetName)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 80, height: 100)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(backgroundTheme == theme ? WWColor.growGreen : Color.clear, lineWidth: 3)
                                        )
                                } else {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(solidThemeBackgroundColor)
                                        .frame(width: 80, height: 100)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(backgroundTheme == theme ? WWColor.growGreen : Color.clear, lineWidth: 3)
                                        )
                                }
                                Text(theme.localizedDisplayName)
                                    .font(WWTypography.caption(12).weight(.medium))
                                    .foregroundStyle(backgroundTheme == theme ? WWColor.nearBlack : WWColor.muted)
                                    .lineLimit(1)
                                    .frame(width: 80)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
            }
        }
    }
    
    private var reviewContent: some View {
        VStack(spacing: 24) {
            Text(copy("review_title", fallback: "Enjoying Tend so far?"))
                .font(WWTypography.display(32))
                .foregroundStyle(WWColor.nearBlack)
                .multilineTextAlignment(.center)

            Text(copy("review_subtitle", fallback: "A quick App Store review helps more people discover Tend."))
                .font(WWTypography.heading(18))
                .foregroundStyle(WWColor.muted)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 12) {
                Button {
                    requestReview()
                    reviewActionTaken = true
                    analytics.track(.reviewPromptShown, properties: ["action": "request_review"])
                } label: {
                    Label(copy("review_primary_button", fallback: "Rate Tend"), systemImage: "star.fill")
                        .font(WWTypography.heading(18))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(WWColor.growGreen)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    reviewActionTaken = true
                    analytics.track(.reviewPromptShown, properties: ["action": "dismiss"])
                } label: {
                    Text(copy("review_secondary_button", fallback: "Not now"))
                        .font(WWTypography.heading(18))
                        .foregroundStyle(WWColor.nearBlack)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(WWColor.surface)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            
            if reviewActionTaken {
                Text(copy("review_thanks_note", fallback: "Thanks for helping Tend grow."))
                    .font(WWTypography.caption(15))
                    .foregroundStyle(WWColor.muted)
            }
        }
    }
    
    // MARK: - Components & Helpers
    
    private var ctaRow: some View {
        HStack(spacing: 12) {
            if step != .intro && step != .generating && step != .creationSprout && step != .firstTendCelebration {
                Button {
                    goBack()
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(WWColor.nearBlack)
                        .frame(width: 56, height: 56)
                        .background(WWColor.surface)
                        .clipShape(Circle())
                }
            }
            
            Button {
                advance()
            } label: {
                HStack {
                    Text(primaryCTAButtonTitle)
                    Image(systemName: "arrow.right")
                }
                .font(WWTypography.heading(20))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(WWColor.growGreen)
                .clipShape(Capsule())
            }
            .disabled(!canAdvance)
            .opacity(canAdvance ? 1 : 0.45)
        }
    }

    private var primaryCTAButtonTitle: String {
        switch step {
        case .intro:
            return copy("intro_primary_cta", fallback: "Get started")
        case .firstTendCelebration:
            return copy("celebration_primary_cta", fallback: "Continue")
        default:
            return isFinalStep
                ? copy("final_primary_cta", fallback: "Continue")
                : copy("default_next_cta", fallback: "Next")
        }
    }
    
    private func optionRow(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(WWTypography.heading(18))
                    .foregroundStyle(selected ? WWColor.nearBlack : WWColor.muted)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(WWColor.growGreen)
                } else {
                    Image(systemName: "circle")
                        .foregroundStyle(WWColor.muted.opacity(0.3))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(selected ? WWColor.growGreen.opacity(0.1) : WWColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(selected ? WWColor.growGreen : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private func suggestionKey(for suggestion: String) -> String {
        switch suggestion {
        case "Trusting God with my anxiety":
            return "prayer_intent_suggestion_1"
        case "Growing consistency in prayer":
            return "prayer_intent_suggestion_2"
        case "Healing in a relationship":
            return "prayer_intent_suggestion_3"
        case "Wisdom for a hard decision":
            return "prayer_intent_suggestion_4"
        default:
            return "prayer_intent_suggestion_custom"
        }
    }

    private func featureBullet(lead: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(WWColor.growGreen)
                .frame(width: 8, height: 8)
                .padding(.top, 8)
            (
                Text(lead).foregroundStyle(WWColor.growGreen) +
                Text(" \(text)").foregroundStyle(WWColor.nearBlack)
            )
            .font(WWTypography.heading(20))
            .lineLimit(2)
        }
    }

    private var defaultPreJourneySteps: [Step] {
        [.prayerIntent, .name, .bannerName, .bannerTruth, .bannerChange, .method, .grounding]
    }

    private var requiredPreJourneySteps: [Step] {
        [.prayerIntent, .name]
    }

    private var fixedFirstJourneySteps: [Step] {
        [.generating, .tendReflection, .tendPrayer, .tendNextStep, .creationSprout]
    }

    private var defaultPostJourneySteps: [Step] {
        supportsWidgetsOnCurrentDevice
            ? [.backgroundSelection, .widget, .reminder, .review]
            : [.backgroundSelection, .reminder, .review]
    }

    private var requiredPostJourneySteps: [Step] {
        supportsWidgetsOnCurrentDevice
            ? [.backgroundSelection, .widget, .reminder, .review]
            : [.backgroundSelection, .reminder, .review]
    }

    private var onboardingFlowSequence: [Step] {
        let pre = canonicalPreJourneyOrder(
            mergeConfiguredSteps(
                configured: resolvedExperimentConfig.preJourneyOrder,
                defaults: defaultPreJourneySteps,
                required: requiredPreJourneySteps
            )
        )
        let post = mergeConfiguredSteps(
            configured: resolvedExperimentConfig.postJourneyOrder,
            defaults: defaultPostJourneySteps,
            required: requiredPostJourneySteps
        )
        return [.intro] + pre + fixedFirstJourneySteps + [.firstTendCelebration] + enforceReviewAsLastPostStep(post)
    }

    private func canonicalPreJourneyOrder(_ steps: [Step]) -> [Step] {
        var reordered: [Step] = []
        for requiredStep in requiredPreJourneySteps where steps.contains(requiredStep) {
            reordered.append(requiredStep)
        }
        reordered.append(contentsOf: steps.filter { !reordered.contains($0) })
        return reordered
    }

    private var isFinalStep: Bool {
        guard let index = onboardingFlowSequence.firstIndex(of: step) else { return false }
        return index == onboardingFlowSequence.count - 1
    }

    private func mergeConfiguredSteps(configured tokens: [String], defaults: [Step], required: [Step]) -> [Step] {
        guard !tokens.isEmpty else { return defaults }

        var result: [Step] = []
        for token in tokens {
            guard let mapped = stepFromToken(token), defaults.contains(mapped), !result.contains(mapped) else { continue }
            result.append(mapped)
        }

        guard !result.isEmpty else { return defaults }

        for requiredStep in required where !result.contains(requiredStep) {
            result.append(requiredStep)
        }

        return result
    }

    private func enforceReviewAsLastPostStep(_ steps: [Step]) -> [Step] {
        var reordered = steps.filter { $0 != .review }
        reordered.append(.review)
        return reordered
    }

    private func stepFromToken(_ token: String) -> Step? {
        let normalized = token.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "name": return .name
        case "banner_name", "bannername": return .bannerName
        case "banner_truth", "bannertruth": return .bannerTruth
        case "banner_change", "bannerchange": return .bannerChange
        case "method": return .method
        case "grounding": return .grounding
        case "prayer_intent", "prayerintent": return .prayerIntent
        case "goal_intent", "goalintent": return .prayerIntent
        case "background_selection", "backgroundselection": return .backgroundSelection
        case "review": return .review
        case "reminder": return .reminder
        case "widget": return .widget
        default: return nil
        }
    }

    private func ensureCurrentStepIsValidForSequence() {
        if !onboardingFlowSequence.contains(step), let first = onboardingFlowSequence.first {
            step = first
        }
    }

    private func copy(_ key: String, fallback: String) -> String {
        let normalizedKey = key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let localizedFallback = L10n.string("onboarding.\(normalizedKey)", default: fallback)
        return resolvedExperimentConfig.copyOverrides[normalizedKey] ?? localizedFallback
    }

    private func applyFirstNamePlaceholder(_ text: String) -> String {
        text
            .replacingOccurrences(of: "{{firstName}}", with: firstNameDisplay)
            .replacingOccurrences(of: "{{firstname}}", with: firstNameDisplay)
    }

    private func topHalfRatio(for step: Step, availableHeight: CGFloat) -> CGFloat {
        let compact = availableHeight < 760

        switch step {
        case .prayerIntent:
            return compact ? 0.23 : 0.28
        case .tendReflection, .tendPrayer, .tendNextStep:
            return compact ? 0.16 : 0.21
        case .widget:
            return compact ? 0.58 : 0.65
        case .name:
            return compact ? 0.24 : 0.30
        case .backgroundSelection:
            return compact ? 0.45 : 0.52
        case .generating:
            return compact ? 0.72 : 0.76
        case .reminder:
            return compact ? 0.14 : 0.18
        case .method, .grounding:
            return compact ? 0.30 : 0.36
        case .bannerName, .bannerTruth, .bannerChange, .review:
            return compact ? 0.20 : 0.25
        case .firstTendCelebration:
            return compact ? 0.48 : 0.54
        case .creationSprout:
            return compact ? 0.52 : 0.58
        case .intro:
            return compact ? 0.40 : 0.45
        }
    }

    private func bottomContentScale(for step: Step, availableHeight: CGFloat) -> CGFloat {
        let base = min(1.0, max(0.90, availableHeight / 852))

        let adjustment: CGFloat
        switch step {
        case .prayerIntent:
            adjustment = availableHeight < 760 ? -0.06 : -0.02
        case .method, .grounding, .reminder, .widget:
            adjustment = availableHeight < 760 ? -0.04 : -0.01
        default:
            adjustment = 0
        }

        return min(1.0, max(0.84, base + adjustment))
    }

    private var isTextEntryStep: Bool {
        switch step {
        case .name, .prayerIntent, .tendNextStep:
            return true
        default:
            return false
        }
    }

    private var ctaClearanceInset: CGFloat {
        switch step {
        case .creationSprout, .generating:
            return 24
        case .firstTendCelebration:
            return 120
        case .tendReflection, .tendPrayer, .tendNextStep:
            // Reserve more space for the persistent CTA row so long generated text
            // can scroll fully above it without appearing truncated.
            return 260
        case .backgroundSelection:
            return 140
        default:
            return 132
        }
    }
    
    private var isBannerStep: Bool {
        step == .bannerName || step == .bannerTruth || step == .bannerChange
    }
    
    private var backgroundColor: Color {
        switch step {
        case .reminder: return WWColor.white
        case .widget: return WWColor.surface
        case .creationSprout:
            return colorScheme == .dark ? WWColor.darkBackground : WWColor.white
        default: return WWColor.white
        }
    }

    private var solidThemeBackgroundColor: Color {
        colorScheme == .dark ? WWColor.darkBackground : WWColor.white
    }
    
    private var canAdvance: Bool {
        switch step {
        case .name: return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .prayerIntent: return !prayerIntentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .tendNextStep: return !actionStepText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .generating: return generatedPackage != nil
        default: return true
        }
    }
    
    private var firstNameDisplay: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Friend" }
        return trimmed
    }

    private func newlineDismissBinding(for source: Binding<String>) -> Binding<String> {
        Binding(
            get: { source.wrappedValue },
            set: { newValue in
                if newValue.contains("\n") {
                    source.wrappedValue = newValue.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
                    focusedField = nil
                } else {
                    source.wrappedValue = newValue
                }
            }
        )
    }
    
    private func advance() {
        guard canAdvance else { return }
        let nextStep = nextStepInFlow()

        if step == .prayerIntent {
            startPreparingJourneyIfNeeded(name: "Friend")
        }

        if nextStep == .generating {
            generatedPackage = nil
            inferredGrowthFocus = ""
            generationIsReady = false
            generationSequencePhase = 0
            withAnimation(.default) { step = .generating }
            Task {
                let prepared = await preparedJourneyForGeneration()
                let result: OnboardingBootstrapResult?
                if let prepared {
                    result = await onCommitPrepared(prepared, firstNameDisplay, prayerIntentText)
                } else {
                    result = await onGenerate(firstNameDisplay, prayerIntentText)
                }

                if let result {
                    await MainActor.run {
                        self.generatedPackage = result.package
                        self.inferredGrowthFocus = result.inferredGrowthFocus.trimmingCharacters(in: .whitespacesAndNewlines)
                        withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                            self.generationIsReady = true
                            self.generationSequencePhase = 2
                        }
                    }
                    let readyHoldNanoseconds: UInt64 = reduceMotion ? 450_000_000 : 850_000_000
                    try? await Task.sleep(nanoseconds: readyHoldNanoseconds)
                    await MainActor.run {
                        guard self.step == .generating else { return }
                        self.advance()
                    }
                } else {
                    await MainActor.run {
                        generationIsReady = false
                        step = .prayerIntent
                    }
                }
            }
            return
        }

        if step == .tendNextStep {
            if let entryID = generatedPackage?.linkedEntryID {
                let descriptor = FetchDescriptor<PrayerEntry>(predicate: #Predicate { $0.id == entryID })
                if let entry = try? modelContext.fetch(descriptor).first {
                    entry.actionStep = actionStepText.trimmingCharacters(in: .whitespacesAndNewlines)
                    entry.completedAt = .now
                    
                    if let journey = entry.journey {
                        journey.completedTends += 1
                        JourneyProgressService.logEvent(journeyID: journey.id, type: .stepCompleted, notes: "Onboarding first tend completed.", modelContext: modelContext)
                        analytics.track(
                            .smallStepCompleted,
                            properties: [
                                "source": "onboarding_first_tend",
                                "journey_id": journey.id.uuidString,
                                "is_first_tend": "true"
                            ]
                        )
                    }
                    try? modelContext.save()
                    WidgetSyncService.publishFromModelContext(modelContext)
                }
            }
        }

        if step == .reminder {
            Task {
                _ = await notificationService.requestAuthorization()
                await notificationService.scheduleReminderSchedules(reminderRows, modelContext: modelContext)
                await MainActor.run { proceedToNextStep() }
            }
            return
        }

        proceedToNextStep()
    }

    private func preparationKey(for prayer: String) -> String {
        prayer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func startPreparingJourneyIfNeeded(name: String) {
        let prayer = prayerIntentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prayer.isEmpty else { return }
        let key = preparationKey(for: prayer)
        if preparedJourneyKey == key, preparedJourney != nil || preparedJourneyTask != nil {
            return
        }
        preparedJourneyKey = key
        preparedJourney = nil
        preparedJourneyTask?.cancel()
        preparedJourneyTask = Task {
            await onPrepare(name, prayer)
        }
    }

    private func preparedJourneyForGeneration() async -> PreparedOnboardingJourney? {
        let prayer = prayerIntentText.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = preparationKey(for: prayer)
        if preparedJourneyKey == key, let preparedJourney {
            return preparedJourney
        }
        if preparedJourneyKey != key || preparedJourneyTask == nil {
            await MainActor.run {
                startPreparingJourneyIfNeeded(name: firstNameDisplay)
            }
        }
        guard let task = preparedJourneyTask else { return nil }
        let prepared = await task.value
        await MainActor.run {
            if preparedJourneyKey == key {
                preparedJourney = prepared
            }
        }
        return prepared
    }

    private func proceedToNextStep() {
        guard let currentIndex = onboardingFlowSequence.firstIndex(of: step) else {
            if let first = onboardingFlowSequence.first {
                step = first
            }
            return
        }

        if currentIndex == onboardingFlowSequence.count - 1 {
            let trimmedInferredGrowthFocus = inferredGrowthFocus.trimmingCharacters(in: .whitespacesAndNewlines)
            let fallbackGrowthFocus = prayerIntentText.trimmingCharacters(in: .whitespacesAndNewlines)
            let profile = OnboardingProfile(
                name: firstNameDisplay,
                ageRange: "",
                prayerFocus: prayerIntentText.trimmingCharacters(in: .whitespacesAndNewlines),
                growthGoal: trimmedInferredGrowthFocus.isEmpty ? fallbackGrowthFocus : trimmedInferredGrowthFocus,
                reminderWindow: "Configured via System",
                blocker: "",
                supportCadence: ""
            )
            onRequirePaywall(.onboardingCompletion)
            onComplete(profile)
            return
        }

        let next = onboardingFlowSequence[currentIndex + 1]
        withAnimation(.default) { step = next }
    }
    
    private func goBack() {
        guard let currentIndex = onboardingFlowSequence.firstIndex(of: step), currentIndex > 0 else { return }
        let previous = onboardingFlowSequence[currentIndex - 1]
        if previous == .generating {
            withAnimation(.default) { step = .prayerIntent }
            return
        }
        withAnimation(.default) { step = previous }
    }

    private func nextStepInFlow() -> Step? {
        guard let currentIndex = onboardingFlowSequence.firstIndex(of: step) else { return nil }
        let nextIndex = currentIndex + 1
        guard onboardingFlowSequence.indices.contains(nextIndex) else { return nil }
        return onboardingFlowSequence[nextIndex]
    }
}

// MARK: - Native Ambient Background
private struct AmbientBannerBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let step: ExperimentalOnboardingFlowView.Step
    
    @State private var animatePhase = false
    
    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            
            ZStack {
                // Orb 1: Morning Gold
                Circle()
                    .fill(WWColor.morningGold.opacity(isStep3 ? 0.5 : 0.3))
                    .frame(width: w * 0.8)
                    .blur(radius: w * 0.25)
                    .offset(
                        x: animatePhase ? w * 0.2 : -w * 0.2,
                        y: animatePhase ? -h * 0.1 : h * 0.2
                    )
                
                // Orb 2: Grow Green
                Circle()
                    .fill(WWColor.growGreen.opacity(isStep2 ? 0.4 : 0.2))
                    .frame(width: w * 0.9)
                    .blur(radius: w * 0.3)
                    .offset(
                        x: animatePhase ? -w * 0.1 : w * 0.3,
                        y: animatePhase ? h * 0.3 : 0
                    )
                    
                // Orb 3: Deep Green (appears later)
                Circle()
                    .fill(WWColor.growGreen.opacity(isStep3 ? 0.3 : 0.0))
                    .frame(width: w * 0.7)
                    .blur(radius: w * 0.2)
                    .offset(
                        x: animatePhase ? w * 0.3 : 0,
                        y: animatePhase ? h * 0.5 : h * 0.2
                    )
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 8).repeatForever(autoreverses: true), value: animatePhase)
            .animation(reduceMotion ? nil : .easeInOut(duration: 1.5), value: step)
            .onAppear {
                animatePhase = true
            }
        }
    }
    
    private var isStep2: Bool {
        step.rawValue >= ExperimentalOnboardingFlowView.Step.bannerTruth.rawValue
    }
    
    private var isStep3: Bool {
        step == .bannerChange
    }
}
