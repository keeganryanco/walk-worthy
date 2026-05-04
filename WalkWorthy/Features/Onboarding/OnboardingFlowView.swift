import StoreKit
import SwiftUI

struct OnboardingFlowView: View {
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

    private struct LayoutMetrics {
        let scale: CGFloat
        let isCompact: Bool
        let isVeryCompact: Bool
        let horizontalPadding: CGFloat
        let topPadding: CGFloat
        let ctaHorizontalPadding: CGFloat
        let ctaBottomPadding: CGFloat
        let introMediaSize: CGFloat
        let widgetHeight: CGFloat

        init(size: CGSize, safeAreaInsets: EdgeInsets) {
            let usableHeight = size.height - safeAreaInsets.top - safeAreaInsets.bottom
            let rawScale = usableHeight / 852

            scale = min(max(rawScale, 0.76), 1.0)
            isCompact = usableHeight < 760
            isVeryCompact = usableHeight < 690
            horizontalPadding = isVeryCompact ? 16 : 24
            topPadding = isVeryCompact ? 14 : 28
            ctaHorizontalPadding = isVeryCompact ? 20 : 28
            ctaBottomPadding = max(12, safeAreaInsets.bottom > 0 ? 12 : 16)
            introMediaSize = isVeryCompact ? 170 : (isCompact ? 194 : 220)
            widgetHeight = isVeryCompact ? 240 : (isCompact ? 292 : 350)
        }
    }

    let onComplete: (OnboardingProfile) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.requestReview) private var requestReview

    @State private var step: Step = .intro

    @State private var name = ""
    @State private var ageRange = ""
    @State private var growIn = ""
    @State private var blocker = ""
    @State private var growthVision = ""
    @State private var supportMode = ""

    @State private var reviewActionTaken = false

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

    private var supportsWidgetsOnCurrentDevice: Bool {
        UIDevice.current.userInterfaceIdiom != .pad
    }

    var body: some View {
        GeometryReader { proxy in
            let metrics = LayoutMetrics(size: proxy.size, safeAreaInsets: proxy.safeAreaInsets)

            ZStack {
                backgroundColor
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    stepContent(metrics: metrics)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .padding(.horizontal, metrics.horizontalPadding)
                        .padding(.top, metrics.topPadding)
                        .padding(.bottom, 12)

                    if step != .creationSprout {
                        bottomCTA
                            .padding(.horizontal, metrics.ctaHorizontalPadding)
                            .padding(.bottom, metrics.ctaBottomPadding)
                            .background(backgroundColor)
                    }
                }
                .ignoresSafeArea(.keyboard, edges: .bottom)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: step)
            }
        }
    }

    private var backgroundColor: Color {
        switch step {
        case .reminder:
            return WWColor.morningGold
        case .widget:
            return WWColor.surface
        case .creationSprout:
            return WWColor.darkBackground
        default:
            return WWColor.white
        }
    }

    @ViewBuilder
    private func stepContent(metrics: LayoutMetrics) -> some View {
        switch step {
        case .intro:
            introScreen(metrics: metrics)
        case .name:
            nameScreen(metrics: metrics)
        case .age:
            ageScreen(metrics: metrics)
        case .bannerName:
            bannerNameScreen(metrics: metrics)
        case .bannerTruth:
            bannerTruthScreen(metrics: metrics)
        case .bannerChange:
            bannerChangeScreen(metrics: metrics)
        case .growIn:
            optionsScreen(
                title: "what are you hoping\nto grow in?",
                options: growInOptions,
                selection: $growIn,
                metrics: metrics
            )
        case .blockers:
            optionsScreen(
                title: "What tends to\nget in the way?",
                options: blockerOptions,
                selection: $blocker,
                metrics: metrics
            )
        case .growthVision:
            optionsScreen(
                title: "What would growth\nlook like for you?",
                options: growthVisionOptions,
                selection: $growthVision,
                metrics: metrics
            )
        case .supportMode:
            optionsScreen(
                title: "how would you like\nTend to support you?",
                options: supportOptions,
                selection: $supportMode,
                metrics: metrics
            )
        case .method:
            methodScreen(metrics: metrics)
        case .grounding:
            groundingScreen(metrics: metrics)
        case .reminder:
            reminderScreen(metrics: metrics)
        case .widget:
            widgetScreen(metrics: metrics)
        case .creationSprout:
            creationSproutScreen(metrics: metrics)
        case .review:
            reviewScreen(metrics: metrics)
        }
    }

    private func introScreen(metrics: LayoutMetrics) -> some View {
        VStack(spacing: 16 * metrics.scale) {
            Spacer(minLength: metrics.isVeryCompact ? 4 : 12)

            OnboardingIntroLoopView(size: metrics.introMediaSize)
                .frame(maxWidth: .infinity)

            Text(L10n.string("onboarding.intro_title", default: "Welcome to Tend"))
                .font(WWTypography.display(displaySize(40, metrics: metrics)))
                .foregroundStyle(WWColor.nearBlack)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.72)

            Text(L10n.string("onboarding.intro_subtitle", default: "Prayer for what you're facing."))
                .font(WWTypography.heading(headingSize(28, metrics: metrics)))
                .foregroundStyle(WWColor.growGreen)
                .minimumScaleFactor(0.75)

            Spacer(minLength: 0)
        }
    }

    private func nameScreen(metrics: LayoutMetrics) -> some View {
        VStack(spacing: 18 * metrics.scale) {
            Spacer(minLength: metrics.isVeryCompact ? 8 : 48)

            Text("what’s your name?")
                .font(WWTypography.display(displaySize(34, metrics: metrics)))
                .foregroundStyle(WWColor.nearBlack)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.72)

            TextField("Enter your name", text: $name)
                .font(WWTypography.heading(headingSize(24, metrics: metrics)))
                .foregroundStyle(WWColor.nearBlack)
                .padding(.horizontal, 20)
                .padding(.vertical, metrics.isVeryCompact ? 12 : 16)
                .background(WWColor.surface)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(WWColor.growGreen, lineWidth: 1))

            Spacer(minLength: 0)
        }
    }

    private func ageScreen(metrics: LayoutMetrics) -> some View {
        VStack(spacing: 12 * metrics.scale) {
            Text("how old are you?")
                .font(WWTypography.display(displaySize(34, metrics: metrics)))
                .foregroundStyle(WWColor.nearBlack)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.72)

            ForEach(ages, id: \.self) { item in
                optionPill(
                    title: item,
                    selected: ageRange == item,
                    metrics: metrics
                ) {
                    ageRange = item
                }
            }

            Spacer(minLength: 0)
        }
    }

    private func bannerNameScreen(metrics: LayoutMetrics) -> some View {
        VStack(spacing: 10 * metrics.scale) {
            Spacer(minLength: 0)

            Text("\(firstNameDisplay), your prayers matter.")
                .font(WWTypography.display(displaySize(32, metrics: metrics)))
                .foregroundStyle(WWColor.nearBlack)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.72)

            (
                Text("so does your ")
                    .font(WWTypography.display(displaySize(32, metrics: metrics)))
                    .foregroundStyle(WWColor.nearBlack)
                + Text("next step.")
                    .font(WWTypography.display(displaySize(32, metrics: metrics)))
                    .foregroundStyle(WWColor.growGreen)
            )
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.72)

            Spacer(minLength: 0)
        }
    }

    private func bannerTruthScreen(metrics: LayoutMetrics) -> some View {
        VStack(spacing: 18 * metrics.scale) {
            Spacer(minLength: 0)

            Text("What you pray can shape\nhow you live.")
                .font(WWTypography.display(displaySize(34, metrics: metrics)))
                .foregroundStyle(WWColor.nearBlack)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.72)

            Text("Tend helps you turn\nyour prayers into your habits,\ndecisions, and daily life.")
                .font(WWTypography.heading(headingSize(24, metrics: metrics)))
                .foregroundStyle(WWColor.nearBlack)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.75)
                .lineLimit(4)

            Spacer(minLength: 0)
        }
    }

    private func bannerChangeScreen(metrics: LayoutMetrics) -> some View {
        VStack(spacing: 20 * metrics.scale) {
            Spacer(minLength: 0)

            Text("What if prayer became\nthe start of real change?")
                .font(WWTypography.display(displaySize(36, metrics: metrics)))
                .foregroundStyle(WWColor.nearBlack)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.72)

            Spacer(minLength: 0)
        }
    }

    private func optionsScreen(
        title: String,
        options: [String],
        selection: Binding<String>,
        metrics: LayoutMetrics
    ) -> some View {
        let twoColumnLayout = options.count > 5
        let columns: [GridItem] = twoColumnLayout
            ? [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
            : [GridItem(.flexible(), spacing: 10)]

        return VStack(spacing: 10 * metrics.scale) {
            Text(title)
                .font(WWTypography.display(displaySize(34, metrics: metrics)))
                .foregroundStyle(WWColor.nearBlack)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
                .lineLimit(3)
                .padding(.bottom, 4)

            LazyVGrid(columns: columns, spacing: metrics.isVeryCompact ? 8 : 10) {
                ForEach(options, id: \.self) { option in
                    optionPill(
                        title: option,
                        selected: selection.wrappedValue == option,
                        metrics: metrics
                    ) {
                        selection.wrappedValue = option
                    }
                }
            }

            Spacer(minLength: 0)
        }
    }

    private func methodScreen(metrics: LayoutMetrics) -> some View {
        VStack(spacing: 16 * metrics.scale) {
            Spacer(minLength: 0)

            Text("Here’s how Tend works")
                .font(WWTypography.display(displaySize(36, metrics: metrics)))
                .foregroundStyle(WWColor.nearBlack)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.72)

            VStack(alignment: .leading, spacing: 12 * metrics.scale) {
                featureBullet(lead: "Pray", text: "about what matters", metrics: metrics)
                featureBullet(lead: "Reflect", text: "with Scripture", metrics: metrics)
                featureBullet(lead: "Choose", text: "one small step", metrics: metrics)
                featureBullet(lead: "Grow", text: "through daily faithfulness", metrics: metrics)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)
        }
    }

    private func groundingScreen(metrics: LayoutMetrics) -> some View {
        VStack(spacing: 16 * metrics.scale) {
            Text("Faith grows when it’s lived.")
                .font(WWTypography.heading(headingSize(32, metrics: metrics)).italic())
                .foregroundStyle(WWColor.nearBlack)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.75)
                .padding(.top, 4)

            WWCard {
                VStack(alignment: .leading, spacing: 10 * metrics.scale) {
                    Text("Tend is built around a simple truth:")
                        .font(WWTypography.heading(headingSize(22, metrics: metrics)))
                        .foregroundStyle(WWColor.nearBlack)
                        .minimumScaleFactor(0.75)

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
                    .font(WWTypography.heading(headingSize(20, metrics: metrics)))
                    .foregroundStyle(WWColor.nearBlack)
                    .minimumScaleFactor(0.75)
                    .lineLimit(7)
                }
            }

            Image("TendMark")
                .resizable()
                .scaledToFit()
                .frame(width: metrics.isVeryCompact ? 44 : 60, height: metrics.isVeryCompact ? 44 : 60)

            Spacer(minLength: 0)
        }
    }

    private func reminderScreen(metrics: LayoutMetrics) -> some View {
        VStack(spacing: 14 * metrics.scale) {
            Image("OnboardingReminderClock")
                .resizable()
                .scaledToFit()
                .frame(width: metrics.isVeryCompact ? 74 : 96, height: metrics.isVeryCompact ? 74 : 96)

            Text("Growth is easier when\nit stays in front of you.")
                .font(WWTypography.display(displaySize(34, metrics: metrics)))
                .foregroundStyle(WWColor.nearBlack)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.72)

            Text("Set a reminder to\nreturn to your prayer journey\nand take your next small step.")
                .font(WWTypography.heading(headingSize(22, metrics: metrics)).italic())
                .foregroundStyle(WWColor.nearBlack)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.75)
                .lineLimit(4)

            Image("OnboardingNotificationsStack")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.black.opacity(0.12), lineWidth: 1)
                )

            Spacer(minLength: 0)
        }
    }

    private func widgetScreen(metrics: LayoutMetrics) -> some View {
        VStack(spacing: 14 * metrics.scale) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.pink.opacity(0.55), Color.blue.opacity(0.65)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: metrics.widgetHeight)
                .overlay {
                    Image("OnboardingNotificationsPhone")
                        .resizable()
                        .scaledToFit()
                        .padding(metrics.isVeryCompact ? 12 : 20)
                }
                .overlay(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.white.opacity(0.78))
                        .frame(height: metrics.isVeryCompact ? 72 : 90)
                        .overlay(alignment: .leading) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\"Cast your cares on Him.\" 1 Peter 5:7")
                                Text("Today’s step: Take 5 minutes to breathe and pray.")
                            }
                            .font(WWTypography.caption(captionSize(13, metrics: metrics)))
                            .foregroundStyle(Color.black)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                            .padding(.horizontal, 12)
                        }
                        .padding(10)
                }

            Text("Keep your journey\nclose.")
                .font(WWTypography.display(displaySize(40, metrics: metrics)))
                .foregroundStyle(WWColor.nearBlack)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.72)

            Text("See your current prayer, verse,\nand next step right\nfrom your home screen.")
                .font(WWTypography.heading(headingSize(22, metrics: metrics)).italic())
                .foregroundStyle(WWColor.nearBlack)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.75)
                .lineLimit(4)

            Spacer(minLength: 0)
        }
    }

    // MARK: - New Screens (Creation Sprout Wow Moment + App Store Review Prompt)

    @State private var sproutOpacity: Double = 0.0
    @State private var sproutScale: Double = 0.4
    @State private var sproutGlow: Double = 0.0

    private func creationSproutScreen(metrics: LayoutMetrics) -> some View {
        VStack(spacing: 24 * metrics.scale) {
            Spacer(minLength: 0)

            ZStack {
                Circle()
                    .fill(WWColor.growGreen.opacity(0.15))
                    .frame(width: metrics.isVeryCompact ? 140 : 180, height: metrics.isVeryCompact ? 140 : 180)
                    .scaleEffect(1.0 + sproutGlow)
                    .opacity(sproutOpacity)
                    .blur(radius: 20)

                Image("TendMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: metrics.isVeryCompact ? 80 : 100, height: metrics.isVeryCompact ? 80 : 100)
                    .scaleEffect(sproutScale)
                    .opacity(sproutOpacity)
            }

            Text("Creating your first journey...")
                .font(WWTypography.heading(headingSize(24, metrics: metrics)))
                .foregroundStyle(WWColor.white)
                .opacity(sproutOpacity)
                .minimumScaleFactor(0.75)

            Spacer(minLength: 0)
        }
        .onAppear {
            if reduceMotion {
                sproutOpacity = 1.0
                sproutScale = 1.0
                sproutGlow = 0.0
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    step = .review
                }
            } else {
                withAnimation(.easeOut(duration: 1.2)) {
                    sproutOpacity = 1.0
                    sproutScale = 1.0
                }
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    sproutGlow = 0.3
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation {
                        step = .review
                    }
                }
            }
        }
    }

    private func reviewScreen(metrics: LayoutMetrics) -> some View {
        VStack(spacing: 18 * metrics.scale) {
            Spacer(minLength: 0)

            Text("Enjoying Tend so far?")
                .font(WWTypography.display(displaySize(36, metrics: metrics)))
                .foregroundStyle(WWColor.nearBlack)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.72)

            Text("A quick App Store review helps more people discover Tend.")
                .font(WWTypography.heading(headingSize(21, metrics: metrics)))
                .foregroundStyle(WWColor.muted)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.75)

            HStack(spacing: 14) {
                Button {
                    requestReview()
                    reviewActionTaken = true
                } label: {
                    Label("Rate Tend", systemImage: "star.fill")
                        .font(WWTypography.heading(headingSize(18, metrics: metrics)))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, metrics.isVeryCompact ? 10 : 12)
                        .background(WWColor.growGreen)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    reviewActionTaken = true
                } label: {
                    Text("Not now")
                        .font(WWTypography.heading(headingSize(18, metrics: metrics)))
                        .foregroundStyle(WWColor.nearBlack)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, metrics.isVeryCompact ? 10 : 12)
                        .background(WWColor.surface)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(WWColor.nearBlack.opacity(0.08), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }

            if reviewActionTaken {
                Text("Thanks for helping Tend grow.")
                    .font(WWTypography.caption(captionSize(15, metrics: metrics)))
                    .foregroundStyle(WWColor.muted)
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Navigation & CTA

    @ViewBuilder
    private var bottomCTA: some View {
        Button(currentButtonTitle) {
            advance()
        }
        .buttonStyle(
            WWPrimaryButtonStyle(
                background: currentButtonBackground,
                foreground: currentButtonForeground
            )
        )
        .disabled(!canAdvance)
        .opacity(canAdvance ? 1 : 0.45)
    }

    private var currentButtonTitle: String {
        switch step {
        case .intro: return "Get started"
        case .reminder: return "Enable reminders"
        case .widget: return "Create my journey"
        case .review: return "Enter Tend"
        default: return "Next"
        }
    }

    private var currentButtonBackground: Color {
        switch step {
        case .reminder: return WWColor.surface
        default: return WWColor.growGreen
        }
    }

    private var currentButtonForeground: Color {
        switch step {
        case .reminder, .widget: return WWColor.nearBlack
        default: return .white
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

    private func optionPill(
        title: String,
        selected: Bool,
        metrics: LayoutMetrics,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(WWTypography.heading(headingSize(metrics.isVeryCompact ? 18 : 22, metrics: metrics)))
                .foregroundStyle(selected ? WWColor.nearBlack : WWColor.muted)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 12)
                .padding(.vertical, metrics.isVeryCompact ? 9 : 12)
                .background(WWColor.surface)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(selected ? WWColor.growGreen : .clear, lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
        }
        .buttonStyle(.plain)
    }

    private func featureBullet(lead: String, text: String, metrics: LayoutMetrics) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(WWColor.growGreen)
                .frame(width: metrics.isVeryCompact ? 8 : 10, height: metrics.isVeryCompact ? 8 : 10)
                .padding(.top, 7)
            (
                Text(lead).foregroundStyle(WWColor.growGreen) +
                Text(" \(text)").foregroundStyle(WWColor.nearBlack)
            )
            .font(WWTypography.heading(headingSize(24, metrics: metrics)))
            .minimumScaleFactor(0.8)
            .lineLimit(2)
        }
    }

    private func displaySize(_ base: CGFloat, metrics: LayoutMetrics) -> CGFloat {
        max(22, base * metrics.scale)
    }

    private func headingSize(_ base: CGFloat, metrics: LayoutMetrics) -> CGFloat {
        max(15, base * metrics.scale)
    }

    private func captionSize(_ base: CGFloat, metrics: LayoutMetrics) -> CGFloat {
        max(12, base * metrics.scale)
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

        if var next = Step(rawValue: step.rawValue + 1) {
            if !supportsWidgetsOnCurrentDevice, next == .widget {
                next = .creationSprout
            }
            withAnimation(.default) {
                step = next
            }
        }
    }
}
