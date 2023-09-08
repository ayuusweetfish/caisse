// 更新基准值，与原始读数取小者
if (base > result) base = result;
// 原始读数与基准值作差，得到过滤读数
result -= base;
// 每隔一段时间尝试增加基准值，以适应环境变化的情形
// 如果环境没有变化，增加量会在下一次刷新时抹去
if (lastBaseIncrement + 1000 < millis()) {
  base++;
  lastBaseIncrement = millis();
}
