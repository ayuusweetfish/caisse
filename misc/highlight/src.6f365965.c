void debouncer_update(struct debouncer *d, int32_t value)
{
  // - snip -
  d->high = max(d->high - 1, min(d->high + 64, value));
  if (value < d->high - 320)
    d->count = min(d->count + 1, 25);
  else
    d->count = max(d->count - 1, 0);
  if (!d->on && d->count >= 15) d->on = true;
  else if (d->on && d->count < 10) d->on = false;
}
