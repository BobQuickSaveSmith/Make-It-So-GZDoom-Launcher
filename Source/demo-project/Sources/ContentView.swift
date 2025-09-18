import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Hello, Make It So!")
                .font(.largeTitle)
                .bold()
            Text("This is a tiny demo app you can build without an Xcode project.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }.frame(minWidth: 420, minHeight: 240)
    }
}
#Preview {
    ContentView()
}
