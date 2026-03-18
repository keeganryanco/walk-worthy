import StoreKit
import SwiftUI

struct ExperimentalOnboardingFlowView: View {
    enum Step: Int, CaseIterable {
        case intro
        case name
        case age
        case bannerName
        case bannerTruth
        case bannerChange
        case growIn
        case blockers
        case growthVision
        case supportMode
        case method
        case grounding
        case reminder
        case widget
        case creationSprout
        case review
    }

    let onComplete: (OnboardingProfile) -> Void

    @Environment(\.requestReview) private var requestReview

    @FocusState private var isNameFocused: Bool

    @State private var step: Step = .intro

    @State private var name = ""
    @State private var ageRange = ""
    @State private var growIn = ""
    @State private var blocker = ""
    @State private var growthVision = ""
    @State private var supportMode = ""

    @State private var reviewActionTaken = false

    private let analytics: AnalyticsTracking = AnalyticsServiceFactory.makeDefault()

    private let ages = ["18-24", "25-34", "35-44", "45-54", "55+"]
    private let growInOptions = [
        "🕊️ peace", "⏱️ discipline", "🌟 confidence", "🌱 patience", "✝️ faith",
        "🧭 purpose", "🤝 relationships", "❤️‍🩹 healing", "🦁 courage", "🔁 consistency"
    ]
    private let blockerOptions = [
        "I overthink", "I lose consistency", "I feel stuck", "I forget", "I don’t know what step to take", "I pray, but don’t follow through"
    ]
    private let growthVisionOptions = [
        "more peace in my day", "better habits", "more trust in God", "more courage to act", "more consistency", "feel less stuck", "more clarity"
    ]
    private let supportOptions = ["daily check-ins", "few times a week", "when I need guidance most"]

    // MARK: - Body
    var body: some View {
        GeometryReader { proxy in
            let safeArea = proxy.safeAreaInsets
            let availableHeight = proxy.size.height - safeArea.top - safeArea.bottom
            let topHalfHeight = availableHeight * topHalfRatio(for: step, availableHeight: availableHeight)
            
            ZStack {
                backgroundColor.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Top Progress Bar
                    if step != .intro && step != .creationSprout && step != .review {
                        progressBar
                            .padding(.horizontal, 24)
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
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                }

                // Fixed CTA Row Overlay
                if step != .creationSprout {
                    VStack {
                        Spacer()
                        ctaRow
                            .padding(.horizontal, 24)
                            .padding(.bottom, max(16, safeArea.bottom))
                    }
                }
            }
            .animation(.easeInOut(duration: 0.35), value: step)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onChange(of: step) { _, newStep in
            if newStep == .name {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    isNameFocused = true
                }
            } else {
                isNameFocused = false
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
            case .name, .age, .growIn, .blockers, .growthVision, .supportMode:
                // Placeholder graphic for input steps
                Image("TendMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: min(height * 0.5, 120))
                    .opacity(0.8)
            case .method:
                 Image("TendMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: min(height * 0.5, 120))
            case .grounding:
                 Image("TendMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: min(height * 0.5, 120))
            case .reminder:
                Image("OnboardingReminderClock")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100)
            case .widget:
                Image("OnboardingNotificationsPhone")
                    .resizable()
                    .scaledToFit()
                    .frame(height: min(height * 0.8, 280))
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

        return VStack(alignment: .leading, spacing: 20) {
            switch step {
            case .intro:
                introContent
            case .name:
                nameContent
            case .age:
                ageContent
            case .bannerName:
                bannerNameContent
            case .bannerTruth:
                bannerTruthContent
            case .bannerChange:
                bannerChangeContent
            case .growIn:
                optionsContent(title: "What are you hoping to grow in?", options: growInOptions, selection: $growIn, twoColumns: true)
            case .blockers:
                optionsContent(title: "What tends to get in the way?", options: blockerOptions, selection: $blocker, twoColumns: false)
            case .growthVision:
                optionsContent(title: "What would growth look like for you?", options: growthVisionOptions, selection: $growthVision, twoColumns: false)
            case .supportMode:
                optionsContent(title: "How would you like Tend to support you?", options: supportOptions, selection: $supportMode, twoColumns: false)
            case .method:
                methodContent
            case .grounding:
                groundingContent
            case .reminder:
                reminderContent
            case .widget:
                widgetContent
            case .creationSprout:
                creationSproutContent
            case .review:
                reviewContent
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
                .focused($isNameFocused)
                .font(WWTypography.heading(22))
                .foregroundStyle(WWColor.nearBlack)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(WWColor.surface)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(WWColor.growGreen.opacity(name.isEmpty ? 0 : 1), lineWidth: 1))
        }
    }
    
    private var ageContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How old are you?")
                .font(WWTypography.display(32))
                .foregroundStyle(WWColor.nearBlack)
            
            VStack(spacing: 10) {
                ForEach(ages, id: \.self) { item in
                    optionRow(title: item, selected: ageRange == item) { ageRange = item }
                }
            }
        }
    }
    
    private func optionsContent(title: String, options: [String], selection: Binding<String>, twoColumns: Bool) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(WWTypography.display(28))
                .foregroundStyle(WWColor.nearBlack)
                .fixedSize(horizontal: false, vertical: true)
            
            if twoColumns {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(options, id: \.self) { item in
                        optionRow(title: item, selected: selection.wrappedValue == item) { selection.wrappedValue = item }
                    }
                }
            } else {
                VStack(spacing: 10) {
                    ForEach(options, id: \.self) { item in
                        optionRow(title: item, selected: selection.wrappedValue == item) { selection.wrappedValue = item }
                    }
                }
            }
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
                .font(WWTypography.display(30))
                .foregroundStyle(WWColor.nearBlack)
            
            Text("Set a reminder to return to your prayer journey and take your next small step.")
                .font(WWTypography.heading(18))
                .foregroundStyle(WWColor.nearBlack.opacity(0.8))
        }
    }
    
    private var widgetContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Keep your journey close.")
                .font(WWTypography.display(32))
                .foregroundStyle(WWColor.nearBlack)
            
            Text("See your current prayer, verse, and next step right from your home screen.")
                .font(WWTypography.heading(18))
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
            if step != .intro {
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
        case .review:
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
        case .age, .growIn, .blockers, .growthVision, .supportMode:
            return compact ? 0.24 : 0.30
        case .name, .method, .grounding, .reminder, .widget:
            return compact ? 0.30 : 0.38
        case .bannerName, .bannerTruth, .bannerChange, .review:
            return compact ? 0.20 : 0.25
        case .creationSprout:
            return compact ? 0.52 : 0.58
        case .intro:
            return compact ? 0.40 : 0.45
        }
    }

    private func bottomContentScale(for step: Step, availableHeight: CGFloat) -> CGFloat {
        let base = min(1.0, max(0.82, availableHeight / 852))

        let adjustment: CGFloat
        switch step {
        case .growIn:
            adjustment = availableHeight < 760 ? -0.14 : -0.08
        case .blockers, .growthVision, .supportMode, .age:
            adjustment = availableHeight < 760 ? -0.10 : -0.04
        case .method, .grounding, .reminder, .widget:
            adjustment = availableHeight < 760 ? -0.06 : -0.02
        default:
            adjustment = 0
        }

        return min(1.0, max(0.72, base + adjustment))
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
        case .age: return !ageRange.isEmpty
        case .growIn: return !growIn.isEmpty
        case .blockers: return !blocker.isEmpty
        case .growthVision: return !growthVision.isEmpty
        case .supportMode: return !supportMode.isEmpty
        default: return true
        }
    }
    
    private var firstNameDisplay: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Friend" }
        return trimmed
    }
    
    private func advance() {
        guard canAdvance else { return }

        if step == .review {
            let profile = OnboardingProfile(
                name: firstNameDisplay,
                ageRange: ageRange,
                prayerFocus: growIn,
                growthGoal: growthVision,
                reminderWindow: supportMode,
                blocker: blocker,
                supportCadence: supportMode
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
