void debouncer_update(struct debouncer *d, int32_t value)
{
  // -- 部分省略 --
  // 高基准值 high 每个时刻至多增加 64 或减少 1
  d->high = max(d->high - 1, min(d->high + 64, value));
  // 取决于当前传感值与基准值之差，增减计数器 count
  if (value < d->high - 320)
    d->count = min(d->count + 1, 25);
  else
    d->count = max(d->count - 1, 0);
  // 根据计数值作迟滞触发判定
  if (!d->on && d->count >= 15) d->on = true;
  else if (d->on && d->count < 10) d->on = false;
}
