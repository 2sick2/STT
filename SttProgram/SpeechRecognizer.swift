import SwiftUI
import Speech
import AVFoundation
import Accelerate


class SpeechRecognizer: ObservableObject {
    @Published var transcript = "말씀해 주세요..."
    @Published var isRecording = false
    @Published var showSavedMessage = false // 저장 알림 표시용
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ko-KR"))!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // 일정 시간 동안 음성이 없으면 녹음을 자동으로 중지하는 타이머
    private var silenceTimer: Timer?
    private let silenceLimit: TimeInterval = 2 // 2초 동안 음성이 없으면 종료
    
    // 텍스트를 파일로 저장하는 함수
    private func saveRecognizedTextToFile() {
        // 텍스트가 비어있는지 확인
        guard !transcript.isEmpty && transcript != "말씀해 주세요..." && transcript != "듣고 있어요..." else {
            print("저장할 텍스트가 없습니다")
            return
        }
        
        do {
            // 문서 디렉토리 경로 가져오기
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            
            // 파일 경로 생성 (고정된 파일명 사용)
            let filePath = documentsPath.appendingPathComponent("stt_command.txt")
            
            // 텍스트를 파일에 저장
            try transcript.write(to: filePath, atomically: true, encoding: .utf8)
            
            print("음성 인식 텍스트가 저장되었습니다: \(filePath)")
            
            // 저장 알림 표시
            DispatchQueue.main.async {
                self.showSavedMessage = true
                // 2초 후 알림 숨기기
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.showSavedMessage = false
                }
            }
        } catch {
            print("파일 저장 오류: \(error)")
        }
    }
    
    // 녹음 시작/중지 함수
    func toggleRecording() {
        if audioEngine.isRunning {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    // 녹음 시작 함수
    private func startRecording() {
        // 이전 작업이 있다면 초기화
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }
        
        // 타이머 초기화
        silenceTimer?.invalidate()
        
        // 오디오 세션 설정
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("오디오 세션 설정 실패: \(error)")
            return
        }
        
        // 인식 요청 객체 생성
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            print("인식 요청 객체를 생성할 수 없습니다.")
            return
        }
        
        // 부분 결과 사용 설정 (말하는 도중에도 텍스트 업데이트)
        recognitionRequest.shouldReportPartialResults = true
        
        // 오디오 입력 노드 가져오기
        let inputNode = audioEngine.inputNode
        
        // 인식 작업 시작
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            var isFinal = false
            
            if let result = result {
                // 인식된 텍스트 업데이트
                DispatchQueue.main.async {
                    self.transcript = result.bestTranscription.formattedString
                }
                isFinal = result.isFinal
                
                // 말하고 있으면 타이머 재설정
                self.resetSilenceTimer()
            }
            
            // 오류가 있거나 최종 결과면 녹음 중지
            if error != nil || isFinal {
                self.stopRecording()
            }
        }
        
        // 오디오 형식 설정
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // 오디오 입력 설정
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
            
            // 음성 레벨 체크로 타이머 재설정
            let level = self?.calculateAudioLevel(buffer: buffer) ?? 0
            if level > 0.01 { // 일정 레벨 이상의 소리가 감지되면
                self?.resetSilenceTimer()
            }
        }
        
        // 오디오 엔진 시작
        audioEngine.prepare()
        do {
            try audioEngine.start()
            // 상태 업데이트
            DispatchQueue.main.async {
                self.isRecording = true
                self.transcript = "듣고 있어요..."
            }
            
            // 첫 타이머 설정
            resetSilenceTimer()
            
        } catch {
            print("오디오 엔진을 시작할 수 없습니다: \(error)")
        }
    }
    
    // 녹음 중지 함수
    private func stopRecording() {
        // 타이머 중지
        silenceTimer?.invalidate()
        silenceTimer = nil
        
        // 오디오 엔진 중지
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        // 인식 요청 종료
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // 상태 업데이트
        DispatchQueue.main.async {
            self.isRecording = false
            
            // 녹음이 완료되면 텍스트 자동 저장
            if self.transcript != "듣고 있어요..." && self.transcript != "말씀해 주세요" {
                self.saveRecognizedTextToFile()
            }
        }
    }
    
    // 침묵 타이머 재설정
    private func resetSilenceTimer() {
        // 기존 타이머 취소
        silenceTimer?.invalidate()
        
        // 새 타이머 설정
        silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceLimit, repeats: false) { [weak self] _ in
            guard let self = self, self.isRecording else { return }
            print("침묵 감지: 녹음 자동 종료")
            self.stopRecording()
        }
    }
    
    // 오디오 레벨 계산 (마이크 볼륨 레벨)
    private func calculateAudioLevel(buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData?[0] else { return 0.0 }
        
        var maxLevel: Float = 0
        
        // 버퍼의 샘플들을 순회하며 최대 레벨 찾기
        vDSP_maxmgv(channelData, 1, &maxLevel, vDSP_Length(buffer.frameLength))
        
        return maxLevel
    }
}
