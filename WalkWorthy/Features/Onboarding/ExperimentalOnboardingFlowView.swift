import StoreKit
import SwiftUI
import SwiftData

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
        case goalIntent
        case generating
        case tendReflection
        case tendPrayer
        case tendNextStep
        case creationSprout
        case review
        case reminder
        case widget
    }

    let onGenerate: (String, String, String) async -> DailyJourneyPackageRecord?
    let onComplete: (OnboardingProfile) -> Void

    @Environment(\.requestReview) private var requestReview
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var notificationService: NotificationService

    @Query(sort: \ReminderSchedule.sortOrder) private var reminderRows: [ReminderSchedule]

    enum Field: Hashable {
        case name, prayer, goal, action
    }
    @FocusState private var focusedField: Field?

    @State private var step: Step = .intro

    @State private var name = ""
    @State private var prayerIntentText = ""
    @State private var goalIntentText = ""
    @State private var actionStepText = ""
    @State private var generatedPackage: DailyJourneyPackageRecord?

    @State private var reviewActionTaken = false

    private let analytics: AnalyticsTracking = AnalyticsServiceFactory.makeDefault()

    private let reminderOptions = ["Morning", "Afternoon", "Evening"]

    // MARK: - Body
    var body: some View {
        GeometryReader { proxy in
            let safeArea = proxy.safeAreaInsets
            let availableHeight = proxy.size.height - safeArea.top - safeArea.bottom
            let topHalfHeight = availableHeight * topHalfRatio(for: step, availableHeight: availableHeight)
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
                    topVisualHalf(metrics: proxy, height: topHalfHeight)
                        .frame(height: topHalfHeight)
                        .frame(maxWidth: .infinity)
                    
                    // Bottom Half: Interactive Controls
                    bottomInteractiveHalf(metrics: proxy, availableHeight: availableHeight)
                        .frame(maxHeight: .infinity)
                        .padding(.horizontal, horizontalInset)
                        .padding(.top, 16)
                }

                // Fixed CTA Row Overlay
                if step != .creationSprout && step != .generating {
                    VStack {
                        Spacer()
                        ctaRow
                            .padding(.horizontal, horizontalInset)
                            .padding(.bottom, max(16, safeArea.bottom))
                    }
                }
            }
            .animation(.easeInOut(duration: 0.35), value: step)
        }
        .onChange(of: step, initial: false) { _, newStep in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                switch newStep {
                case .name: focusedField = .name
                case .prayerIntent: focusedField = .prayer
                case .goalIntent: focusedField = .goal
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
    }
    
    // MARK: - Layout Areas
    
    private var progressBar: some View {
        let totalSteps = Step.allCases.count - 4 // Ignore intro, sprout, review, etc
        let currentIndex = max(0, step.rawValue - 1)
        
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
            case .name, .prayerIntent, .goalIntent, .generating, .tendReflection, .tendPrayer, .tendNextStep:
                // Placeholder graphic for input steps
                Image("TendMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: min(height * 0.56, 136))
                    .opacity(0.8)
            case .method:
                 Image("TendMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: min(height * 0.56, 136))
            case .grounding:
                 Image("TendMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: min(height * 0.56, 136))
            case .reminder:
                Image("OnboardingReminderClock")
                    .resizable()
                    .scaledToFit()
                    .frame(width: min(height * 0.48, 132))
            case .widget:
                Image("OnboardingNotificationsPhone")
                    .resizable()
                    .scaledToFit()
                    .frame(height: min(height * 0.92, 340))
            case .creationSprout:
                ZStack {
                    Circle()
                        .fill(WWColor.growGreen.opacity(0.15))
                        .frame(width: 180, height: 180)
                        .scaleEffect(1.0 + sproutGlow)
                        .opacity(sproutOpacity)
                        .blur(radius: 20)

                    Image("TendMark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .scaleEffect(sproutScale)
                        .opacity(sproutOpacity)
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
            case .goalIntent:
                goalIntentContent
            case .generating:
                generatingContent
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
            case .review:
                reviewContent
            case .reminder:
                reminderContent
            case .widget:
                widgetContent
            case .creationSprout:
                creationSproutContent
            }
        }
        .frame(maxWidth: .infinity, alignment: step == .intro || isBannerStep ? .center : .leading)
        .scaleEffect(contentScale, anchor: .top)
        .frame(maxHeight: .infinity, alignment: .top)
    }
    
    // MARK: - Step Contents (Bottom Half)
    
    private var introContent: some View {
        VStack(spacing: 12) {
            Text("Welcome to Tend")
                .font(WWTypography.display(36))
                .foregroundStyle(WWColor.nearBlack)
                .multilineTextAlignment(.center)
            
            Text("pray. act. grow.")
                .font(WWTypography.heading(24))
                .foregroundStyle(WWColor.growGreen)
            
            Text("turn your prayers into small\nsteps of real growth")
                .font(WWTypography.heading(18).italic())
                .foregroundStyle(WWColor.muted)
                .multilineTextAlignment(.center)
                .padding(.top, 16)
        }
    }
    
    private var nameContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What's your name?")
                .font(WWTypography.display(32))
                .foregroundStyle(WWColor.nearBlack)
            
            TextField("Enter your name", text: $name)
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
            Text("What do you want to pray about right now?")
                .font(WWTypography.display(34))
                .foregroundStyle(WWColor.nearBlack)
                .fixedSize(horizontal: false, vertical: true)

            TextField("My prayer is...", text: newlineDismissBinding(for: $prayerIntentText), axis: .vertical)
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
        }
    }

    private var goalIntentContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What goal are you moving toward with God right now?")
                .font(WWTypography.display(34))
                .foregroundStyle(WWColor.nearBlack)
                .fixedSize(horizontal: false, vertical: true)

            TextField("My goal is...", text: newlineDismissBinding(for: $goalIntentText), axis: .vertical)
                .focused($focusedField, equals: .goal)
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
                        .stroke(WWColor.growGreen.opacity(goalIntentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0 : 1), lineWidth: 1)
                )
                .shadow(color: WWColor.nearBlack.opacity(0.04), radius: 10, x: 0, y: 4)
        }
    }
    
    private var generatingContent: some View {
        VStack(spacing: 24) {
            ProgressView()
                .tint(WWColor.growGreen)
                .scaleEffect(1.5)
            Text("Designing your journey...")
                .font(WWTypography.heading(24))
                .foregroundStyle(WWColor.nearBlack)
        }
        .frame(maxWidth: .infinity)
    }

    private var tendReflectionContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your first step is ready.")
                .font(WWTypography.display(36))
                .foregroundStyle(WWColor.nearBlack)
            
            WWCard {
                VStack(alignment: .leading, spacing: 16) {
                    Text(generatedPackage?.scriptureReference ?? "Scripture")
                        .font(WWTypography.caption(12).weight(.bold))
                        .foregroundStyle(WWColor.growGreen)
                        .tracking(1.0)
                    
                    Text(generatedPackage?.scriptureParaphrase ?? "...")
                        .font(WWTypography.heading(20))
                        .foregroundStyle(WWColor.nearBlack)
                    
                    Divider()
                    
                    Text(generatedPackage?.reflectionThought ?? "...")
                        .font(WWTypography.body(17))
                        .foregroundStyle(WWColor.muted)
                }
            }
        }
    }

    private var tendPrayerContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Take a moment to pray.")
                .font(WWTypography.display(36))
                .foregroundStyle(WWColor.nearBlack)
            
            Text("Read this prayer drawn from your intent and scripture.")
                .font(WWTypography.heading(19))
                .foregroundStyle(WWColor.muted)
            
            WWCard {
                Text(generatedPackage?.prayer ?? "...")
                    .font(WWTypography.body(17))
                    .foregroundStyle(WWColor.nearBlack)
                    .italic()
            }
        }
    }

    private var tendNextStepContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose your first step.")
                .font(WWTypography.display(34))
                .foregroundStyle(WWColor.nearBlack)
            
            Text(generatedPackage?.smallStepQuestion ?? "What is one small step you can take today?")
                .font(WWTypography.heading(20))
                .foregroundStyle(WWColor.nearBlack)
            
            TextField("My next step is...", text: newlineDismissBinding(for: $actionStepText), axis: .vertical)
                .focused($focusedField, equals: .action)
                .submitLabel(.done)
                .onSubmit { focusedField = nil }
                .font(WWTypography.heading(20))
                .foregroundStyle(WWColor.nearBlack)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(minHeight: 130, alignment: .top)
                .background(WWColor.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(WWColor.growGreen.opacity(actionStepText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0 : 1), lineWidth: 1)
                )
                .shadow(color: WWColor.nearBlack.opacity(0.04), radius: 10, x: 0, y: 4)
        }
    }
    
    private var bannerNameContent: some View {
        VStack(spacing: 16) {
            Text("\(firstNameDisplay), your prayers matter.")
                .font(WWTypography.display(32))
                .foregroundStyle(WWColor.nearBlack)
                .multilineTextAlignment(.center)

            (
                Text("so does your ")
                    .font(WWTypography.display(32))
                    .foregroundStyle(WWColor.nearBlack)
                + Text("next step.")
                    .font(WWTypography.display(32))
                    .foregroundStyle(WWColor.growGreen)
            )
            .multilineTextAlignment(.center)
        }
    }
    
    private var bannerTruthContent: some View {
        VStack(spacing: 20) {
            Text("What you pray can shape\nhow you live.")
                .font(WWTypography.display(32))
                .foregroundStyle(WWColor.nearBlack)
                .multilineTextAlignment(.center)

            Text("Tend helps you turn\nyour prayers into your habits,\ndecisions, and daily life.")
                .font(WWTypography.heading(22))
                .foregroundStyle(WWColor.nearBlack)
                .multilineTextAlignment(.center)
        }
    }
    
    private var bannerChangeContent: some View {
        VStack(spacing: 20) {
            Text("What if prayer became\nthe start of real change?")
                .font(WWTypography.display(36))
                .foregroundStyle(WWColor.nearBlack)
                .multilineTextAlignment(.center)
        }
    }
    
    private var methodContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Here’s how Tend works")
                .font(WWTypography.display(32))
                .foregroundStyle(WWColor.nearBlack)
                .padding(.bottom, 8)
            
            VStack(alignment: .leading, spacing: 14) {
                featureBullet(lead: "Pray", text: "about what matters")
                featureBullet(lead: "Reflect", text: "with Scripture")
                featureBullet(lead: "Choose", text: "one small step")
                featureBullet(lead: "Grow", text: "through daily faithfulness")
            }
        }
    }
    
    private var groundingContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Faith grows when it’s lived.")
                .font(WWTypography.heading(28).italic())
                .foregroundStyle(WWColor.nearBlack)
            
            WWCard {
                VStack(alignment: .leading, spacing: 12) {
                    (
                        Text("what ").foregroundStyle(WWColor.growGreen)
                        + Text("you pray can shape ")
                        + Text("how ").foregroundStyle(WWColor.growGreen)
                        + Text("you live, and small ")
                        + Text("faithful steps ").foregroundStyle(WWColor.growGreen)
                        + Text("can bear ")
                        + Text("real fruit").foregroundStyle(WWColor.growGreen)
                        + Text(" over time.")
                    )
                    .font(WWTypography.heading(18))
                    .foregroundStyle(WWColor.nearBlack)
                }
            }
        }
    }
    
    private var reminderContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Growth is easier when it stays in front of you.")
                .font(WWTypography.display(32))
                .foregroundStyle(WWColor.nearBlack)
            
            Text("Set a reminder to return to your prayer journey and take your next small step.")
                .font(WWTypography.heading(18))
                .foregroundStyle(WWColor.nearBlack.opacity(0.8))

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
                    .listRowBackground(WWColor.white)
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
                    Label("Add Reminder", systemImage: "plus.circle.fill")
                        .foregroundStyle(WWColor.growGreen)
                        .font(WWTypography.heading(16))
                }
                .listRowBackground(WWColor.white)
            }
            .listStyle(.plain)
            .background(WWColor.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: WWColor.nearBlack.opacity(0.04), radius: 10, x: 0, y: 4)
            .frame(height: 180)
        }
    }
    
    private var widgetContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Keep your journey close.")
                .font(WWTypography.display(36))
                .foregroundStyle(WWColor.nearBlack)
            
            Text("See your current prayer, verse, and next step right from your home screen.")
                .font(WWTypography.heading(20))
                .foregroundStyle(WWColor.nearBlack.opacity(0.8))
        }
    }
    
    @State private var sproutOpacity: Double = 0.0
    @State private var sproutScale: Double = 0.4
    @State private var sproutGlow: Double = 0.0
    
    private var creationSproutContent: some View {
        VStack {
            Text("Creating your first journey...")
                .font(WWTypography.heading(24))
                .foregroundStyle(WWColor.white)
                .opacity(sproutOpacity)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(.easeOut(duration: 1.2)) {
                sproutOpacity = 1.0
                sproutScale = 1.0
            }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                sproutGlow = 0.3
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation { step = .review }
            }
        }
    }
    
    private var reviewContent: some View {
        VStack(spacing: 24) {
            Text("Enjoying Tend so far?")
                .font(WWTypography.display(32))
                .foregroundStyle(WWColor.nearBlack)
                .multilineTextAlignment(.center)

            Text("A quick App Store review helps more people discover Tend.")
                .font(WWTypography.heading(18))
                .foregroundStyle(WWColor.muted)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 12) {
                Button {
                    requestReview()
                    reviewActionTaken = true
                    analytics.track(.reviewPromptShown, properties: ["action": "request_review"])
                } label: {
                    Label("Rate Tend", systemImage: "star.fill")
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
                    Text("Not now")
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
                Text("Thanks for helping Tend grow.")
                    .font(WWTypography.caption(15))
                    .foregroundStyle(WWColor.muted)
            }
        }
    }
    
    // MARK: - Components & Helpers
    
    private var ctaRow: some View {
        HStack(spacing: 12) {
            if step != .intro && step != .generating && step != .creationSprout {
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
            return "Get started"
        case .widget:
            return "Enter Tend"
        default:
            return "Next"
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

    private func topHalfRatio(for step: Step, availableHeight: CGFloat) -> CGFloat {
        let compact = availableHeight < 760

        switch step {
        case .prayerIntent, .goalIntent:
            return compact ? 0.26 : 0.31
        case .widget:
            return compact ? 0.36 : 0.44
        case .name, .method, .grounding, .reminder, .generating, .tendReflection, .tendPrayer, .tendNextStep:
            return compact ? 0.34 : 0.42
        case .bannerName, .bannerTruth, .bannerChange, .review:
            return compact ? 0.20 : 0.25
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
        case .goalIntent:
            adjustment = availableHeight < 760 ? -0.05 : -0.02
        case .method, .grounding, .reminder, .widget:
            adjustment = availableHeight < 760 ? -0.04 : -0.01
        default:
            adjustment = 0
        }

        return min(1.0, max(0.84, base + adjustment))
    }
    
    private var isBannerStep: Bool {
        step == .bannerName || step == .bannerTruth || step == .bannerChange
    }
    
    private var backgroundColor: Color {
        switch step {
        case .reminder: return WWColor.morningGold
        case .widget: return WWColor.surface
        case .creationSprout: return WWColor.darkBackground
        default: return WWColor.white
        }
    }
    
    private var canAdvance: Bool {
        switch step {
        case .name: return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .prayerIntent: return !prayerIntentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .goalIntent: return !goalIntentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

        if step == .goalIntent {
            withAnimation(.default) { step = .generating }
            Task {
                if let pkg = await onGenerate(firstNameDisplay, prayerIntentText, goalIntentText) {
                    await MainActor.run {
                        self.generatedPackage = pkg
                        self.advance()
                    }
                } else {
                    await MainActor.run { step = .goalIntent }
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
                    }
                    try? modelContext.save()
                    WidgetSyncService.publishFromModelContext(modelContext)
                }
            }
        }

        if step == .reminder {
            Task {
                _ = await notificationService.requestAuthorization()
                await notificationService.scheduleReminderSchedules(reminderRows)
                await MainActor.run { proceedToNextStep() }
            }
            return
        }

        proceedToNextStep()
    }

    private func proceedToNextStep() {
        if step == .widget {
            let profile = OnboardingProfile(
                name: firstNameDisplay,
                ageRange: "",
                prayerFocus: prayerIntentText.trimmingCharacters(in: .whitespacesAndNewlines),
                growthGoal: goalIntentText.trimmingCharacters(in: .whitespacesAndNewlines),
                reminderWindow: "Configured via System",
                blocker: "",
                supportCadence: ""
            )
            onComplete(profile)
            return
        }

        if let next = Step(rawValue: step.rawValue + 1) {
            withAnimation(.default) { step = next }
        }
    }
    
    private func goBack() {
        if let prev = Step(rawValue: step.rawValue - 1) {
            withAnimation(.default) { step = prev }
        }
    }
}

// MARK: - Native Ambient Background
private struct AmbientBannerBackground: View {
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
            .animation(.easeInOut(duration: 8).repeatForever(autoreverses: true), value: animatePhase)
            .animation(.easeInOut(duration: 1.5), value: step)
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
