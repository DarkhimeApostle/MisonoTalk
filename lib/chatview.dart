import 'package:flutter/material.dart';
import 'utils.dart' show Message;

class ChatElement extends StatelessWidget {
  final String message;
  final int type;
  final String stuName;
  final bool isRead;
  const ChatElement(
      {super.key,
      required this.message,
      required this.type,
      required this.stuName,
      this.isRead = false});

  @override
  Widget build(BuildContext context) {
    if (type == Message.assistant) {
      // 隐藏 Thinking... 消息
      if (message.startsWith("Thinking...")) {
        return const SizedBox.shrink();
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var m in message.split("\\\\"))
          if (m.isNotEmpty)
            ChatBubbleLayoutLeft(name: stuName, messages: m.split("\\")),
        const SizedBox(height: 10),
      ]);
    } else if (type == Message.user) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ChatBubbleLayoutRight(messages: message.split("\\"), isRead: isRead),
          const SizedBox(height: 10),
        ],
      );
    } else if (type == Message.timestamp) {
      DateTime t = DateTime.fromMillisecondsSinceEpoch(int.parse(message));
      String timestr = "${t.hour.toString().padLeft(2, '0')}:"
          "${t.minute.toString().padLeft(2, '0')}";
      return centerBubble(timestr);
    } else if (type == Message.system) {
      return centerBubble("System Instruction Here");
    } else if (type == Message.image) {
      return ChatBubbleImage(name: stuName, imageUrl: message);
    } else {
      return const SizedBox.shrink();
    }
  }
}

Widget centerBubble(String msg) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Container(
        decoration: BoxDecoration(
          color: const Color(0xffdce5ec),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: Text(
          msg,
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xff4c5b70),
          ),
        ),
      ),
      const SizedBox(height: 5),
    ],
  );
}

class ChatBubbleLayoutLeft extends StatelessWidget {
  final String name;
  final List<String> messages;

  const ChatBubbleLayoutLeft({
    super.key,
    required this.name,
    required this.messages,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(
            width: 50,
            child: Padding(
                padding: EdgeInsets.only(top: 7),
                child: CircleAvatar(
                  backgroundImage: AssetImage("assets/avatar.png"),
                  radius: 25,
                ))),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              ...messages.asMap().entries.map((entry) {
                int idx = entry.key;
                String message = entry.value.trim();
                bool isStar = message.startsWith("*") ||
                    message.startsWith("（") ||
                    message.startsWith("(");
                if (message.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: CustomPaint(
                    painter: BubblePainter(
                        isFirstBubble: idx == 0,
                        isLeft: true,
                        bubbleColor: isStar
                            ? const Color(0x884c5b70)
                            : const Color(0xff4c5b70)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: Text(
                        message,
                        style: isStar
                            ? const TextStyle(fontSize: 10, color: Colors.white)
                            : const TextStyle(
                                fontSize: 18, color: Colors.white),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}

class ChatBubbleImage extends StatelessWidget {
  final String name;
  final String imageUrl;

  const ChatBubbleImage({
    super.key,
    required this.name,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
            padding: EdgeInsets.only(top: 7),
            child: CircleAvatar(
              backgroundImage: AssetImage("assets/avatar.png"),
              radius: 25,
            )),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: FractionallySizedBox(
                              widthFactor: 0.8,
                              child: Image.network(
                                imageUrl,
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                  if (loadingProgress == null) {
                                    return child;
                                  } else {
                                    return Center(
                                      child: CircularProgressIndicator(
                                        value: loadingProgress
                                                    .expectedTotalBytes !=
                                                null
                                            ? loadingProgress
                                                    .cumulativeBytesLoaded /
                                                loadingProgress
                                                    .expectedTotalBytes!
                                            : null,
                                      ),
                                    );
                                  }
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(Icons.error);
                                },
                              )))),
                ),
              )
            ],
          ),
        ),
      ],
    );
  }
}

// No name and avatar
class ChatBubbleLayoutRight extends StatelessWidget {
  final List<String> messages;
  final bool isRead;

  const ChatBubbleLayoutRight({
    super.key,
    required this.messages,
    this.isRead = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        ...messages.asMap().entries.map((entry) {
          int idx = entry.key;
          String message = entry.value;
          if (message.isEmpty) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // 为已读标识预留固定空间，确保布局一致性
                SizedBox(
                  width: 50, // 固定宽度，为已读标识预留空间
                  child: idx == messages.length - 1 && isRead
                      ? Align(
                          alignment: Alignment.bottomLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color.fromARGB(255, 200, 204, 209),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: const Text(
                                "已读",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color.fromARGB(243, 255, 255, 255),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        )
                      : null, // 当不需要显示已读标识时，保持占位但不显示内容
                ),
                Flexible(
                  child: CustomPaint(
                    painter: BubblePainter(
                        isFirstBubble: idx == 0,
                        isLeft: false,
                        bubbleColor: const Color(0xff4a8aca)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: Text(
                        message,
                        style:
                            const TextStyle(fontSize: 18, color: Colors.white),
                        softWrap: true,
                        overflow: TextOverflow.visible,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class BubblePainter extends CustomPainter {
  final bool isFirstBubble;
  final bool isLeft;
  final Color bubbleColor;

  BubblePainter(
      {required this.isFirstBubble,
      required this.isLeft,
      required this.bubbleColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = bubbleColor
      ..style = PaintingStyle.fill;

    final path = Path();

    if (isFirstBubble) {
      // 自适应三角形位置 - 根据气泡高度动态计算
      if (isLeft) {
        // 计算气泡中心高度
        double centerY = size.height / 2;
        // 三角形宽度
        double triangleWidth = 10.0;
        // 三角形高度
        double triangleHeight = 15.0;

        path.moveTo(-triangleWidth / 2, centerY);
        path.lineTo(triangleWidth / 2, centerY - triangleHeight / 2);
        path.lineTo(triangleWidth / 2, centerY + triangleHeight / 2);
        path.close();
      } else {
        // 右侧气泡的三角形 - 优化位置计算
        double centerY = size.height / 2;
        double triangleWidth = 6.0;
        double triangleHeight = 10.0;

        // 确保三角形指向气泡中心，并考虑文本的实际高度
        // 如果气泡高度很小，调整三角形大小
        if (size.height < 20) {
          triangleHeight = size.height * 0.4; // 小气泡使用更小的三角形
        }

        // 用户消息的三角小尾巴向右偏移，避免与气泡边缘重叠 
        double offset = 3.0; //
        path.moveTo(size.width + triangleWidth / 2 + offset, centerY);
        path.lineTo(size.width - triangleWidth / 2 + offset,
            centerY - triangleHeight / 2);
        path.lineTo(size.width - triangleWidth / 2 + offset,
            centerY + triangleHeight / 2);
        path.close();
      }
    }

    // Draw rounded rectangle for the bubble
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    path.addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)));

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
