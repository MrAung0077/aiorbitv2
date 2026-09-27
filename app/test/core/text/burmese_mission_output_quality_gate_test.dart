import 'package:aiorbit/core/text/burmese_mission_output_quality_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const gate = BurmeseMissionOutputQualityGate();

  test('rejects Armenian text inserted into Burmese output', () {
    final assessment = gate.assess(
      'ပစ်မှတ်ပရိသတ်ကို သတ်မှတ်ပါ။ Եթե assumptions လိုပါက',
    );

    expect(
      assessment.issues,
      contains(BurmeseMissionOutputQualityIssue.unexpectedForeignScript),
    );
  });

  test('rejects Korean text inserted into Burmese output', () {
    final assessment = gate.assess('အကြောင်းအရာအစီအစဉ်ကို ပြင်ဆင်ပါ။ 아니면');

    expect(
      assessment.issues,
      contains(BurmeseMissionOutputQualityIssue.unexpectedForeignScript),
    );
  });

  test('accepts Burmese output with only allowed standard English terms', () {
    final assessment = gate.assess(
      'Facebook Reel အတွက် Caption, Hook နဲ့ CTA ကို ပထမအပတ်မှာ စမ်းသပ်ပါ။',
    );

    expect(assessment.isAcceptable, isTrue);
  });

  test('rejects mostly English headings for a Burmese task', () {
    final assessment = gate.assess(
      'Target audience\n'
      'Content strategy\n'
      'Production workflow\n'
      'Supporting assets\n'
      'Posting schedule',
    );

    expect(
      assessment.issues,
      contains(BurmeseMissionOutputQualityIssue.excessiveUnnecessaryEnglish),
    );
  });

  test('rejects internal Mission orchestration leakage', () {
    final assessment = gate.assess(
      'Reserved upcoming task scopes: Caption writing\n'
      'အခုအဆင့်မှာ ပစ်မှတ်ပရိသတ်ကိုသာ သတ်မှတ်ပါ။',
    );

    expect(
      assessment.issues,
      contains(BurmeseMissionOutputQualityIssue.internalOrchestrationLeakage),
    );
  });

  test('allows an explicitly requested foreign script', () {
    final assessment = gate.assess(
      'ကိုရီးယားစာ အမည်: 안녕하세요',
      allowUnexpectedForeignScripts: true,
    );

    expect(assessment.isAcceptable, isTrue);
  });
}
