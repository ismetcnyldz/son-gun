// Kaydı telefonun kendi takvimine ekle
import 'package:add_2_calendar/add_2_calendar.dart';

import 'models.dart';
import 'notify.dart';

Future<bool> addToCalendar(Item it) async {
  final due = it.nextDue();
  if (due == null) return false;
  final start = DateTime(due.year, due.month, due.day, Notifier.hour, Notifier.minute);
  final event = Event(
    title: '${it.title}: son gün',
    description: [if (it.note.isNotEmpty) it.note, if (it.amount != null) 'Tutar: ${fmtMoney(it.amount!)}', 'Son Gün uygulamasından eklendi.'].join('\n'),
    startDate: start,
    endDate: start.add(const Duration(hours: 1)),
    allDay: true,
    iosParams: const IOSParams(reminder: Duration(days: 1)),
    recurrence: it.kind.monthly ? Recurrence(frequency: Frequency.monthly) : null,
  );
  return Add2Calendar.addEvent2Cal(event);
}
