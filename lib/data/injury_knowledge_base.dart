import '../models/injury_model.dart';

class InjuryKnowledgeBase {
  /// Danh mục các chấn thương thể thao cầu lông chuẩn
  static final List<InjuryType> allInjuries = [
    // 1. Tennis Elbow (Khuỷu tay ngoài)
    const InjuryType(
      id: 'tennis_elbow',
      nameVi: 'Viêm gân lồi cầu ngoài (Tennis Elbow)',
      medicalName: 'Lateral Epicondylitis',
      bodyPart: BodyPart.elbow,
      description:
          'Tình trạng viêm hoặc vi rách các sợi gân cơ duỗi cẳng tay bám vào mỏm lồi cầu ngoài xương cánh tay. Đây là chấn thương phổ biến số 1 ở người chơi cầu lông khi ve trái tay (backhand) hoặc đan cước quá căng làm xung chấn dội thẳng vào tay.',
      primarySymptoms: [
        'Đau nhói mặt ngoài khuỷu tay',
        'Đau tăng khi thực hiện quả ve trái tay (backhand)',
        'Yếu lực cầm nắm (khó mở nắp chai, vặn chìa khóa)',
        'Đau khi duỗi cổ tay ngửa lên có lực cản',
        'Cảm giác thốn lan dọc xuống mặt sau cẳng tay',
      ],
      riceProtocol:
          '• Rest: Ngừng đánh cầu ngay lập tức ít nhất 10 - 14 ngày.\n• Ice: Chườm túi đá lạnh bọc khăn 15-20 phút, ngày 3-4 lần để giảm viêm.\n• Compression: Đeo đai ép băng khuỷu tay (Counterforce Elbow Strap) cách điểm đau 2cm về phía cẳng tay.\n• Elevation: Giữ tay thả lỏng cao ngang tim khi nghỉ ngơi.',
      gearAdvice: GearAdvice(
        tensionAdvice:
            'Hạ mức căng cước xuống 23 - 25 lbs (tối đa 25.5 lbs). Căng quá 27 lbs triệt tiêu độ trợ lực khiến lực chấn truyền thẳng vào khuỷu tay.',
        racketSpecAdvice:
            'Chuyển sang vợt thân dẻo hoặc trung bình (Flexible/Medium Shaft), trọng lượng nhẹ hơn (4U hoặc 5U), điểm cân bằng Even-balance (285-295mm).',
        stringAdvice:
            'Dùng cước có tính đàn hồi cao, đường kính 0.65 - 0.66mm như Yonex BG66 Ultimax, Li-Ning No.1, Kizuna Z65 giúp giảm rung chấn.',
        otherAdvice:
            'Đổi sang quấn cán mềm có đệm giảm sốc (Cushion Wrap lót trong).',
      ),
      exercises: [
        RehabExercise(
          id: 'te_1',
          name: 'Kéo giãn cơ duỗi cẳng tay (Wrist Extensor Stretch)',
          targetPart: 'Gân cơ lồi cầu ngoài',
          durationOrReps: 'Giữ 20-30 giây, lặp lại 3-4 hiệp',
          instructions:
              'Duỗi thẳng cánh tay đau ra trước mặt, lòng bàn tay úp xuống. Dùng tay còn lại nhẹ nhàng kéo gập các ngón tay và bàn tay xuống dưới cho đến khi thấy căng êm ở mặt ngoài cẳng tay.',
          cautionNote: 'Chỉ kéo tới mức căng dễ chịu, không gượng ép khi đau nhói.',
        ),
        RehabExercise(
          id: 'te_2',
          name: 'Bài tập gập cổ tay lệch tâm với tạ nhẹ (Eccentric Wrist Extension)',
          targetPart: 'Cơ duỗi cổ tay',
          durationOrReps: '10 - 15 lần/hiệp, 2 hiệp/ngày',
          instructions:
              'Ngồi tựa cẳng tay lên bàn, cổ tay thò ra ngoài mép bàn với chai nước nhỏ (0.5L) hoặc tạ 0.5-1kg. Dùng tay lành nâng tạ lên, sau đó dùng tay đau từ từ hạ tạ xuống trong vòng 3-4 giây.',
          cautionNote: 'Chỉ tập khi giai đoạn viêm cấp đã giảm (sau 5-7 ngày).',
        ),
      ],
    ),

    // 2. Golfer's Elbow (Khuỷu tay trong)
    const InjuryType(
      id: 'golfers_elbow',
      nameVi: 'Viêm gân lồi cầu trong (Golfer\'s Elbow)',
      medicalName: 'Medial Epicondylitis',
      bodyPart: BodyPart.elbow,
      description:
          'Tổn thương gân nhóm cơ gập cổ tay bám vào mỏm trong khuỷu tay. Thường gặp khi người chơi có thói quen gập cổ tay quá đà khi đập cầu (smash) hoặc chặt cầu.',
      primarySymptoms: [
        'Đau nhức mặt trong khuỷu tay',
        'Đau thốn khi gập cổ tay úp xuống hoặc bóp chặt cán vợt',
        'Đau khi phát lực đập cầu (smash) từ phía trên đầu',
        'Có thể có cảm giác tê râm ran lan xuống ngón út và áp út',
      ],
      riceProtocol:
          '• Rest: Tạm ngưng các động tác đập smash và cắt cầu trong 2 tuần.\n• Ice: Chườm lạnh mặt trong khuỷu tay 15 phút sau khi vận động nhẹ.\n• Compression: Băng thun hỗ trợ khớp khuỷu tay.\n• Kháng viêm tự nhiên: Ngâm nước muối ấm sau 72h đầu.',
      gearAdvice: GearAdvice(
        tensionAdvice:
            'Giảm 1-2 lbs so với mức căng quen thuộc để tạo độ nảy tự nhiên.',
        racketSpecAdvice:
            'Tránh dùng các cây vợt quá nặng đầu (Head-Heavy >305mm) vì làm tăng mô-men uốn lên mặt trong khuỷu tay.',
        stringAdvice: 'Dùng cước trợ lực có lõi sợi giảm chấn (Multifilament).',
        otherAdvice:
            'Tập lại kỹ thuật phát lực toàn thân (kinetic chain) thay vì chỉ gập cổ tay.',
      ),
      exercises: [
        RehabExercise(
          id: 'ge_1',
          name: 'Kéo giãn cơ gập cẳng tay (Wrist Flexor Stretch)',
          targetPart: 'Gân cơ lồi cầu trong',
          durationOrReps: 'Giữ 20 giây x 3 hiệp',
          instructions:
              'Duỗi thẳng tay ra phía trước, lòng bàn tay ngửa lên trời. Dùng tay kia kéo nhẹ các ngón tay gập xuống dưới sàn.',
          cautionNote: 'Thở đều, không giật mạnh tay.',
        ),
      ],
    ),

    // 3. TFCC / Tổn thương sụn sợi tam giác cổ tay
    const InjuryType(
      id: 'wrist_tfcc',
      nameVi: 'Tổn thương phức hợp sụn sợi tam giác (TFCC cổ tay)',
      medicalName: 'Triangular Fibrocartilage Complex Tear',
      bodyPart: BodyPart.wrist,
      description:
          'Tổn thương sụn và dây chằng nối giữa xương trụ và khối xương cổ tay (phía bên ngón út). Chấn thương xảy ra khi xoay vặn cổ tay đột ngột với lực phát mạnh (đặc biệt khi chụp lưới hoặc ve trái tay muộn).',
      primarySymptoms: [
        'Đau thốn ở phía bên ngón út của cổ tay',
        'Đau tăng khi xoay chìa khóa hoặc bẻ cổ tay về phía ngón út',
        'Khớp cổ tay kêu lạo xạo hoặc cảm giác "lỏng lẻo"',
        'Đau dữ dội khi chống tay xuống mặt phẳng đứng dậy',
      ],
      riceProtocol:
          '• Cố định: Đeo nẹp cố định cổ tay (Wrist Splint) giữ khớp trung tính.\n• Rest: Nghỉ thi đấu 2 - 4 tuần.\n• Ice: Chườm đá 15 phút, 3 lần/ngày.\n• Lưu ý: Nếu có tiếng lách cách kèm đau buốt kéo dài, cần chụp MRI chuyên khoa.',
      gearAdvice: GearAdvice(
        tensionAdvice:
            'Hạ mức căng xuống dưới 24 lbs. Tránh tuyệt đối cước đan trên 28 lbs.',
        racketSpecAdvice:
            'Dùng vợt cân bằng, trọng lượng 4U hoặc 5U (nhẹ hơn 85g), cán vợt kích thước vừa tay G5.',
        stringAdvice: 'Cước có lực trợ tốt (repulsion power).',
        otherAdvice:
            'Luôn đeo băng quấn bảo vệ cổ tay (Wrist Bandage) khi tập luyện trở lại.',
      ),
      exercises: [
        RehabExercise(
          id: 'tfcc_1',
          name: 'Bài tập xoay cẳng tay không tạ (Pronation & Supination)',
          targetPart: 'Cơ sấp ngửa cẳng tay',
          durationOrReps: '15 lần quay mỗi chiều x 2 hiệp',
          instructions:
              'Cẳng tay để vuông góc 90 độ tựa vào hông. Chậm rãi lật ngửa bàn tay lên trần rồi xoay úp bàn tay xuống sàn một cách có kiểm soát.',
          cautionNote: 'Dừng ngay nếu cảm thấy đau chói ở rìa ngón út.',
        ),
      ],
    ),

    // 4. Viêm bao gân De Quervain (Cổ tay ngón cái)
    const InjuryType(
      id: 'wrist_de_quervain',
      nameVi: 'Hội chứng viêm bao gân De Quervain',
      medicalName: 'De Quervain\'s Tenosynovitis',
      bodyPart: BodyPart.wrist,
      description:
          'Viêm màng bao gân của hai gân điều khiển ngón tay cái (gân cơ dạng dài và duỗi ngắn ngón cái) ngay tại gốc cổ tay. Phổ biến khi người chơi bóp cán vợt quá chặt và bẻ gập ngón cái khi tạt lưới.',
      primarySymptoms: [
        'Đau và sưng nề ở gốc ngón tay cái sát cổ tay',
        'Nghiệm pháp Finkelstein dương tính (Nắm ngón cái vào lòng bàn tay rồi uốn cổ tay xuống thấy đau chói)',
        'Cảm giác dính khớp hoặc cọ xát khi cử động ngón cái',
      ],
      riceProtocol:
          '• Nẹp ngón cái: Dùng nẹp cố định khớp bàn ngón tay cái.\n• Hạn chế bóp chặt các vật dụng.\n• Chườm lạnh vùng gốc ngón cái 15 phút.',
      gearAdvice: GearAdvice(
        tensionAdvice: 'Mức căng vừa phải 22 - 24 lbs.',
        racketSpecAdvice: 'Chọn cán vợt vừa vặn (không quá to hoặc quá bé).',
        stringAdvice: 'Cước mềm êm ái.',
        otherAdvice: 'Thay quấn cán mới có độ bám cao để không phải gồng ngón tay.',
      ),
      exercises: [
        RehabExercise(
          id: 'dq_1',
          name: 'Giãn gân ngón cái nhẹ nhàng',
          targetPart: 'Bao gân ngón cái',
          durationOrReps: '15 giây x 3 hiệp',
          instructions:
              'Mở rộng bàn tay, nhẹ nhàng đưa ngón cái hướng ra ngoài xa các ngón khác đến khi cảm thấy căng nhẹ ở gốc ngón cái rồi thả lỏng.',
          cautionNote: 'Không giật mạnh ngón cái.',
        ),
      ],
    ),

    // 5. Viêm gân chóp xoay vai (Rotator Cuff)
    const InjuryType(
      id: 'rotator_cuff',
      nameVi: 'Viêm gân chóp xoay khớp vai',
      medicalName: 'Rotator Cuff Tendinopathy',
      bodyPart: BodyPart.shoulder,
      description:
          'Tổn thương một hoặc nhiều gân trong nhóm 4 cơ chóp xoay vai (đặc biệt gân trên gai Supraspinatus). Chấn thương do động tác vung tay smash trên đầu lặp đi lặp lại với vợt quá nặng hoặc thiếu khởi động kỹ khớp vai.',
      primarySymptoms: [
        'Đau âm ỉ sâu bên trong khớp vai',
        'Đau buốt khi giơ tay qua đầu góc 60 - 120 độ (Cung đau vai)',
        'Khó nằm nghiêng sang bên vai bị đau khi ngủ',
        'Mất sức rõ rệt khi phông cầu cao sâu hoặc smash',
      ],
      riceProtocol:
          '• Rest: Ngừng hoàn toàn các cú đánh smash và phông cầu cao qua đầu.\n• Ice: Chườm đá quanh chỏm vai 15-20 phút sau khi tập nhẹ.\n• Thuốc: Tham khảo bác sĩ dùng kháng viêm không steroid (NSAIDs) nếu đau nhiều.',
      gearAdvice: GearAdvice(
        tensionAdvice: 'Giảm 1-2 lbs để tăng độ nảy tự nhiên của mặt vợt.',
        racketSpecAdvice:
            'Đổi từ vợt nặng đầu (Head-Heavy >300mm) sang vợt cân bằng (290mm) hoặc nhẹ đầu. Chuyển từ 3U sang 4U/5U để giảm quán tính xoay (Swingweight).',
        stringAdvice: 'Dùng cước trợ lực có tiếng nổ đanh trợ lực tối đa.',
        otherAdvice:
            'Khởi động khớp vai ít nhất 7-10 phút trước khi vào sân bằng dây kháng lực.',
      ),
      exercises: [
        RehabExercise(
          id: 'rc_1',
          name: 'Xoay ngoài khớp vai với dây kháng lực (External Shoulder Rotation)',
          targetPart: 'Cơ dưới gai & cơ tròn bé',
          durationOrReps: '12-15 lần x 3 hiệp',
          instructions:
              'Khuỷu tay gập 90 độ ép sát hông, tay cầm dây kháng lực hoặc chai nước nhẹ. Kéo cẳng tay xoay ra ngoài từ từ, giữ 1 giây rồi thả về.',
          cautionNote: 'Giữ chặt khuỷu tay sát sườn, không nhấc nách.',
        ),
      ],
    ),

    // 6. Viêm gân bánh chè (Jumper's Knee)
    const InjuryType(
      id: 'jumpers_knee',
      nameVi: 'Viêm gân bánh chè (Jumper\'s Knee)',
      medicalName: 'Patellar Tendinopathy',
      bodyPart: BodyPart.knee,
      description:
          'Viêm gân nối giữa xương bánh chè và xương chày. Chấn thương do lực tải cực lớn lên gân bánh chè khi bật nhảy smash cầu và tiếp đất dồn trọng tâm trên một chân.',
      primarySymptoms: [
        'Đau nhói ngay dưới xương bánh chè',
        'Đau tăng khi bước dồn chân (lunge) đón cầu lưới hoặc leo cầu thang',
        'Cứng khớp gối vào buổi sáng sau ngày thi đấu nặng',
        'Ấn vào cực dưới xương bánh chè thấy điểm đau rõ rệt',
      ],
      riceProtocol:
          '• Rest: Tránh bật nhảy smash, chỉ tập các bài tập không tải trọng.\n• Ice: Chườm đá trực tiếp dưới xương bánh chè 15 phút.\n• Đai gối: Đeo đai bó gân bánh chè (Patellar Strap) khi vận động đi lại.',
      gearAdvice: GearAdvice(
        tensionAdvice: 'Không ảnh hưởng trực tiếp.',
        racketSpecAdvice: 'Không ảnh hưởng trực tiếp.',
        stringAdvice: 'Không ảnh hưởng trực tiếp.',
        otherAdvice:
            'Kiểm tra giày cầu lông: Lớp đệm đĩa Cushion/Power Cushion có bị xẹp lún không? Nên đổi giày mới nếu đã dùng > 8 tháng hoặc chơi trên sân bê tông không thảm.',
      ),
      exercises: [
        RehabExercise(
          id: 'jk_1',
          name: 'Ngồi tựa lưng vào tường tĩnh (Wall Sit Isometric)',
          targetPart: 'Gân bánh chè & Cơ tứ đầu đùi',
          durationOrReps: 'Giữ 30 - 45 giây x 3 hiệp',
          instructions:
              'Tựa lưng phẳng vào tường, hạ đùi xuống góc 60-90 độ như ngồi trên ghế. Giữ yên tư thế, trọng tâm dồn vào gót chân.',
          cautionNote: 'Không hạ gối quá sâu nếu thấy đau nhói.',
        ),
      ],
    ),

    // 7. Lật sơ mi cổ chân (Ankle Sprain)
    const InjuryType(
      id: 'ankle_sprain',
      nameVi: 'Lật sơ mi / Bong gân khớp cổ chân',
      medicalName: 'Lateral Ankle Sprain',
      bodyPart: BodyPart.ankle,
      description:
          'Giãn hoặc rách dây chằng sên mác trước (ATFL) ở mắt cá ngoài cổ chân khi bàn chân bị lật vào trong trong lúc tiếp đất hoặc phanh gấp.',
      primarySymptoms: [
        'Sưng to và bầm tím ở mắt cá chân ngoài',
        'Đau nhói khi dồn trọng lượng cơ thể lên chân đau',
        'Cảm giác lỏng khớp hoặc sợ chịu lực',
        'Cử động xoay cổ chân bị hạn chế nghiêm trọng',
      ],
      riceProtocol:
          '• Rest: Dùng nạng hỗ trợ, không cố đi cà nhắc.\n• Ice: Chườm đá lạnh 20 phút mỗi 2-3 giờ trong 48h đầu.\n• Compression: Băng ép mắt cá bằng băng thun số 8.\n• Elevation: Nằm gác chân cao hơn tim để thoát dịch phù nề.',
      gearAdvice: GearAdvice(
        tensionAdvice: 'Không liên quan đến vợt.',
        racketSpecAdvice: 'Không liên quan đến vợt.',
        stringAdvice: 'Không liên quan đến vợt.',
        otherAdvice:
            'Đổi giày cầu lông có đế chống lật (Anti-torsion Carbon Plate / Claw design bên hông). Xỏ dây giày chặt đến lỗ trên cùng.',
      ),
      exercises: [
        RehabExercise(
          id: 'as_1',
          name: 'Viết bảng chữ cái bằng mũi chân (Alphabet Ankle Draw)',
          targetPart: 'Dây chằng & Biên độ cổ chân',
          durationOrReps: 'Vẽ chữ A đến Z x 2 lần',
          instructions:
              'Ngồi kê cao chân, dùng ngón chân cái làm bút vẽ từng chữ cái trên không trung nhằm khôi phục tầm vận động khớp cổ chân.',
          cautionNote: 'Tập từ tốn sau khi sưng cấp đã xẹp (sau ngày thứ 3).',
        ),
      ],
    ),

    // 8. Căng cơ thắt lưng (Lower Back Strain)
    const InjuryType(
      id: 'lumbar_strain',
      nameVi: 'Căng giãn cơ thắt lưng',
      medicalName: 'Lumbar Muscle Strain',
      bodyPart: BodyPart.back,
      description:
          'Co thắt hoặc vi chấn thương nhóm cơ cạnh cột sống thắt lưng khi người chơi phải ngửa lưng quá mức (hyperextension) để cứu cầu bị đối thủ đánh lọt ra sau lưng.',
      primarySymptoms: [
        'Đau nhức ê ẩm vùng thắt lưng, lan sang 2 bên cơ dựng sống',
        'Cứng lưng khó cúi người hoặc xoay hông',
        'Cơ thắt lưng co cứng nổi cộm khi sờ vào',
        'Không có triệu chứng tê buốt giật điện lan xuống bàn chân',
      ],
      riceProtocol:
          '• Rest: Nằm ngửa kê gối dưới khoeo chân để giải phóng áp lực đĩa đệm.\n• Nhiệt trị liệu: Chườm lạnh trong 48h đầu, sau đó chườm ấm thư giãn cơ.\n• Tránh ngồi khom lưng lâu.',
      gearAdvice: GearAdvice(
        tensionAdvice: 'Không ảnh hưởng.',
        racketSpecAdvice:
            'Nên chọn vợt có tính khí động học (Aero Frame) giúp vung vợt thoát gió nhanh hơn, giảm áp lực uốn lưng khi cứu cầu muộn.',
        stringAdvice: 'Cước trợ lực tốt.',
        otherAdvice: 'Tập cải thiện bộ pháp di chuyển lùi về (Chassé step).',
      ),
      exercises: [
        RehabExercise(
          id: 'lb_1',
          name: 'Tư thế Cat - Cow (Mèo - Bò)',
          targetPart: 'Cột sống thắt lưng & cơ lõi',
          durationOrReps: '10 nhịp thở chậm x 2 hiệp',
          instructions:
              'Quỳ 4 điểm trên thảm. Hít vào võng lưng ngẩng mặt lên nhẹ nhàng, thở ra uốn cong lưng rút rốn lên trần nhà.',
          cautionNote: 'Chuyển động mượt mà, không giật mạnh.',
        ),
      ],
    ),
  ];

  /// Thuật toán Chẩn đoán & Đối soát Bệnh học + Dụng cụ
  static InjuryDiagnosisResult diagnose(InjuryAssessmentInput input) {
    // 1. Lọc các chấn thương tiềm năng theo vùng cơ thể
    final matchingInjuries =
        allInjuries.where((i) => i.bodyPart == input.bodyPart).toList();

    InjuryType selectedInjury = matchingInjuries.isNotEmpty
        ? matchingInjuries.first
        : allInjuries.first;

    int bestScore = 0;

    for (final injury in matchingInjuries) {
      int score = 0;
      // So khớp triệu chứng
      for (final sym in input.selectedSymptoms) {
        for (final primary in injury.primarySymptoms) {
          if (sym.toLowerCase().contains(primary.toLowerCase().split(' ').first) ||
              primary.toLowerCase().contains(sym.toLowerCase())) {
            score += 2;
          }
        }
      }

      // So khớp hành động kích hoạt
      final act = input.triggerAction.toLowerCase();
      if (injury.id == 'tennis_elbow' && (act.contains('ve') || act.contains('backhand'))) {
        score += 3;
      } else if (injury.id == 'golfers_elbow' && (act.contains('smash') || act.contains('đập'))) {
        score += 3;
      } else if (injury.id == 'rotator_cuff' && (act.contains('smash') || act.contains('phông'))) {
        score += 3;
      } else if (injury.id == 'jumpers_knee' && (act.contains('nhảy') || act.contains('lunge'))) {
        score += 3;
      } else if (injury.id == 'ankle_sprain' && (act.contains('tiếp đất') || act.contains('trượt'))) {
        score += 4;
      }

      if (score > bestScore) {
        bestScore = score;
        selectedInjury = injury;
      }
    }

    // 2. Phân tích tương quan dụng cụ (Gear Factors)
    final gearInsights = <String>[];
    bool isGearFactorHigh = false;

    if (input.racketTensionLbs != null && input.racketTensionLbs! > 0) {
      if (input.racketTensionLbs! >= 28.0) {
        isGearFactorHigh = true;
        gearInsights.add(
          'Mức căng ${input.racketTensionLbs} lbs của vợt là rất cao (>28 lbs), làm giảm triệt để độ trợ lực mặt lưới và dội toàn bộ phản lực xung chấn trực tiếp vào khớp ${input.bodyPart.shortLabel.toLowerCase()}.',
        );
      } else if (input.racketTensionLbs! >= 26.5 &&
          (input.bodyPart == BodyPart.elbow || input.bodyPart == BodyPart.wrist)) {
        isGearFactorHigh = true;
        gearInsights.add(
          'Mức căng ${input.racketTensionLbs} lbs khá căng với người chơi phong trào, dễ gây quá tải dây chằng cổ tay và gân khuỷu tay.',
        );
      }
    }

    if (input.racketShaftStiffness != null) {
      final stiff = input.racketShaftStiffness!.toLowerCase();
      if ((stiff.contains('rất cứng') || stiff.contains('cứng')) &&
          (input.bodyPart == BodyPart.elbow || input.bodyPart == BodyPart.shoulder)) {
        isGearFactorHigh = true;
        gearInsights.add(
          'Đũa vợt có độ cứng "${input.racketShaftStiffness}" đòi hỏi tốc độ vung phát lực cực nhanh; nếu chưa hoàn thiện kỹ thuật sẽ tạo áp lực quá tải lớn lên vai và khuỷu tay.',
        );
      }
    }

    if (input.racketBalanceMm != null && input.racketBalanceMm! >= 300) {
      if (input.bodyPart == BodyPart.shoulder || input.bodyPart == BodyPart.wrist) {
        isGearFactorHigh = true;
        gearInsights.add(
          'Vợt thiên công nặng đầu (${input.racketBalanceMm}mm) tạo ra lực ly tâm và mô-men xoắn lớn, làm tăng gánh nặng cho chóp xoay vai khi smash liên tục.',
        );
      }
    }

    if (input.racketTensionLossPercent != null && input.racketTensionLossPercent! >= 20.0) {
      gearInsights.add(
        'Cước trên cây vợt đã bị chùng -${input.racketTensionLossPercent}%, mặt vợt bị rung lắc và mất độ nảy chuẩn, khiến bạn phải gồng cơ nhiều hơn để đánh cầu về cuối sân.',
      );
    }

    final gearSummary = gearInsights.isNotEmpty
        ? gearInsights.join('\n\n')
        : 'Chưa phát hiện tương quan bất thường từ thông số vợt. Chấn thương chủ yếu do kỹ thuật vận động hoặc quá tải cường độ thi đấu.';

    // 3. Đánh giá mức độ nghiêm trọng & An toàn ra sân
    final severity = PainSeverity.fromScore(input.painScore);
    final canPlay = severity == PainSeverity.mild && input.painScore <= 3;

    String safeAdvice;
    if (severity == PainSeverity.severe) {
      safeAdvice =
          'TUYỆT ĐỐI KHÔNG RA SÂN! Chấn thương đang ở mức báo động cao, nguy cơ tổn thương nặng thêm nếu tiếp tục vận động.';
    } else if (severity == PainSeverity.moderate) {
      safeAdvice =
          'TẠM NGƯNG THI ĐẤU 1 - 2 TUẦN. Nên tập trung nghỉ ngơi theo phác đồ R.I.C.E và tập vật lý trị liệu phục hồi.';
    } else {
      safeAdvice =
          'CÓ THỂ VẬN ĐỘNG NHẸ. Hãy đeo băng bảo hộ khớp, khởi động thật kỹ 10 phút và tuyệt đối không smash quá sức.';
    }

    // 4. Tính toán độ tin cậy chuẩn đoán (Confidence %)
    int confidence = 75 + (bestScore * 4);
    if (confidence > 95) confidence = 95;

    return InjuryDiagnosisResult(
      injuryType: selectedInjury,
      confidencePercent: confidence,
      severity: severity,
      gearAnalysisSummary: gearSummary,
      isGearFactorHigh: isGearFactorHigh,
      canPlayBadmintonNow: canPlay,
      safeToPlayAdvice: safeAdvice,
    );
  }
}
