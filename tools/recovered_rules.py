"""Small statically recovered rule subset, with original uint32 arithmetic.

Sources: docs/binary-analysis.md and analysis/svMapServer-selected.asm.
Inputs are already-effective stats: equipment/status aggregation is not ported.
This is not a complete RedMoon rules engine.
"""
UINT32_MAX = (1 << 32) - 1


def _uint32(value: int) -> int:
    if type(value) is not int or not 0 <= value <= UINT32_MAX:
        raise ValueError("Expected unsigned 32-bit integer")
    return value


def hp_max(effective_power: int) -> int:
    """InitializeHPMax, VA 0x4346c0; effective input after status/equipment."""
    power = _uint32(effective_power)
    return (50 + (power // 15) * (power // 10)) & UINT32_MAX


def mp_max(effective_spirit: int) -> int:
    """InitializeMPMax, VA 0x434780; effective input after equipment."""
    spirit = _uint32(effective_spirit)
    if spirit <= 20_000:
        return (50 + (spirit // 15) * (spirit // 10)) & UINT32_MAX
    return (273 * spirit - 0x2A9DF6) & UINT32_MAX


def level_up_bonus_points(new_level: int) -> int:
    """The base bonus increment in DoLevelUp; excludes other rewards/quests."""
    if type(new_level) is not int or not 1 <= new_level <= UINT32_MAX:
        raise ValueError("Expected positive unsigned 32-bit new level")
    return 3 if new_level % 100 == 0 else 2
