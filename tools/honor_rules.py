"""Ordinary non-arena GetMopFame arithmetic (server VA 0x439a10).

Quest flags select caps 100/200/300/400/500/1000. Only the initial, no-quest cap
is integrated. This implements signed reputation changes, not quest rewards.
"""
def honor_after_kill(current: int, reputation: int, cap: int=100) -> int:
    if not all(type(v) is int for v in (current,reputation,cap)) or cap<1:
        raise ValueError('Expected integer honor, reputation and positive cap')
    if reputation==0:return current
    step=min(10,(abs(reputation)-1)//100+1)*(1 if reputation>0 else -1)
    if current==0:return -step
    if current>0:
        if step>0:return max(0,current-step)
        return min(cap,current-step) if current<cap else current
    if step<0:return min(0,current-step)
    return max(-cap,current-step) if current>-cap else current
