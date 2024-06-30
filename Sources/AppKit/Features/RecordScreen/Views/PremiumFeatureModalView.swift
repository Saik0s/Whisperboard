//
//  PremiumFeatureModalView.swift
//  WhisperBoardKit
//
//  Created by Igor Tarasenko on 30/06/2024.
//

import SwiftUI

struct PremiumFeatureModalView: View {
  var body: some View {
    VStack(spacing: 20) {
      HeaderView()
      FeatureListView()
      PurchaseButton()
    }
    .padding()
  }
}

struct HeaderView: View {
  var body: some View {
    VStack(spacing: 10) {
      Text("Revolutionize Your World with Live Transcription")
        .font(.largeTitle)
        .fontWeight(.bold)
        .multilineTextAlignment(.center)
      
      Text("It's not just amazing. It's magical.")
        .font(.title2)
        .fontWeight(.medium)
      
      HStack(spacing: 2) {
        ForEach(0..<5) { _ in
          Image(systemName: "star.fill")
            .foregroundColor(.yellow)
        }
      }
      
      Text("This changes everything. The way we communicate, the way we work, the way we live. It's a quantum leap in human interaction.")
        .font(.body)
        .multilineTextAlignment(.center)
        .padding(.horizontal)
      
      Text("- Steve Jobs")
        .font(.footnote)
        .foregroundColor(.gray)
    }
  }
}

struct FeatureListView: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 15) {
      FeatureItemView(icon: "waveform", text: "Real-time Speech-to-Text")
      FeatureItemView(icon: "globe", text: "Multi-language Support")
      FeatureItemView(icon: "brain", text: "AI-powered Accuracy")
      FeatureItemView(icon: "bolt.fill", text: "Lightning-fast Processing")
      FeatureItemView(icon: "person.2.fill", text: "Speaker Identification")
      FeatureItemView(icon: "doc.text.fill", text: "Instant Editable Transcripts")
      FeatureItemView(icon: "icloud.fill", text: "Seamless Cloud Integration")
      FeatureItemView(icon: "lock.shield.fill", text: "Privacy-first Design")
    }
  }
}

struct FeatureItemView: View {
  let icon: String
  let text: String
  
  var body: some View {
    HStack {
      Image(systemName: icon)
        .foregroundColor(.blue)
      Text(text)
        .font(.body)
    }
  }
}

struct PurchaseButton: View {
  var body: some View {
    Button(action: {
      // Perform in-app purchase action
    }) {
      Text("Experience the Future")
        .font(.system(size: 20, weight: .semibold))
        .foregroundColor(.white)
        .padding(.horizontal, 30)
        .frame(height: 50)
        .background(Color.blue)
        .cornerRadius(25)
    }
  }
}
