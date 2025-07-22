              // 祝福アニメーションオーバーレイ
              if (_showCelebration)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.8),
                    child: Center(
                      child: SingleChildScrollView(
                        child: Container(
                          width: MediaQuery.of(context).size.width * 0.85,
                          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // ラットのアニメーション
                              SlideTransition(
                                position: _ratSlideAnimation,
                                child: Image.asset(
                                  'assets/images/rat_celebration.png',
                                  height: 120,
                                ),
                              ),
                              const SizedBox(height: 20),
                              
                              // タスク達成バッジ（優先タスク用）
                              if (widget.task.isPriority)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.amber,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text('優先タスク達成!', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              const SizedBox(height: 16),
                              
                              // おめでとうメッセージ
                              Text(
                                '${widget.task.name} 達成!!',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueGrey,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              
                              // タスク結果の詳細
                              Text(
                                '続けた時間: ${_formatTime(widget.task.duration * 60 - _remainingSeconds)}',
                                style: const TextStyle(fontSize: 18),
                              ),
                              const SizedBox(height: 15),
                              
                              // スマホタッチ回数表示
                              Text(
                                'スマホを触った回数: $_phoneInteractionCount回',
                                style: const TextStyle(fontSize: 18),
                              ),
                              const SizedBox(height: 15),
                              // 集中度選択UI
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: _showConcentrationError ? Colors.red : Colors.grey.shade300,
                                    width: _showConcentrationError ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '集中度を評価してください',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: _showConcentrationError ? Colors.red : Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    _buildConcentrationOption(ConcentrationLevel.high, 'かなり集中できた'),
                                    _buildConcentrationOption(ConcentrationLevel.medium, '集中できた'),
                                    _buildConcentrationOption(ConcentrationLevel.low, '集中できなかった'),
                                    if (_showConcentrationError)
                                      const Padding(
                                        padding: EdgeInsets.only(top: 8),
                                        child: Text(
                                          'このタスクでの集中度を選択してください',
                                          style: TextStyle(color: Colors.red, fontSize: 14),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 15),
                              // メモ用テキストフィールドを追加
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: TextField(
                                  controller: _memoController,
                                  decoration: const InputDecoration(
                                    hintText: '感想やメモを入力してください',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.all(12),
                                  ),
                                  maxLines: 3,
                                  textAlign: TextAlign.left,
                                ),
                              ),
                              const SizedBox(height: 20),
                              
                              // 閉じるボタン
                              ElevatedButton.icon(
                                icon: const Icon(Icons.close),
                                label: const Text('閉じる'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  textStyle: const TextStyle(fontSize: 18),
                                ),
                                onPressed: () {
                                  // 集中度が選択されていない場合はエラーメッセージを表示
                                  if (_concentrationLevel == null) {
                                    setState(() {
                                      _showConcentrationError = true;
                                    });
                                    return;
                                  }
                                  
                                  // セッションデータを保存
                                  _saveSessionData();
                                  
                                  // ホーム画面に戻る（全てのルートを削除してホームに移動）
                                  Navigator.of(context).pushNamedAndRemoveUntil(
                                    '/', // ホーム画面のルート
                                    (route) => false, // すべてのルートを削除
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
