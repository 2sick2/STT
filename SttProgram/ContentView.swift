import SwiftUI

struct ContentView: View {
    @StateObject private var speechRecognizer = SpeechRecognizer()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("음성 인식 (STT)")
                .font(.largeTitle)
                .padding()
            
            // 인식된 텍스트 표시 영역
            Text(speechRecognizer.transcript)
                .padding()
                .frame(maxWidth: .infinity)
                .frame(height: 150)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(10)
                .padding(.horizontal)
            
            // 녹음 시작/중지 버튼만 표시
            Button(action: {
                speechRecognizer.toggleRecording()
            }) {
                VStack {
                    Image(systemName: speechRecognizer.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(speechRecognizer.isRecording ? .red : .blue)
                    Text(speechRecognizer.isRecording ? "녹음 중지" : "음성 인식 시작")
                        .font(.headline)
                }
                .frame(width: 160, height: 120)
                .background(Color.white)
                .cornerRadius(10)
                .shadow(radius: 3)
            }
            .padding()
            
            // 파일 저장 알림 메시지 (자동으로 나타났다 사라짐)
            if speechRecognizer.showSavedMessage {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("텍스트 파일이 저장되었습니다!")
                }
                .padding()
                .background(Color.green.opacity(0.2))
                .cornerRadius(10)
                .transition(.opacity)
                .animation(.easeInOut, value: speechRecognizer.showSavedMessage)
            }
            
            // 사용 방법 설명
            VStack(alignment: .leading, spacing: 8) {
                Text("사용 방법:")
                    .font(.headline)
                Text("1. 녹음하고 싶은 내용을 말하세요")
                Text("3. 말하기를 멈추면 2초 후 자동으로 녹음이 종료됩니다")
                Text("4. 텍스트 파일이 자동으로 저장됩니다")
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(10)
            .padding()
            
            Spacer()
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
