"""Verify translations against recovered x86 arithmetic, not a mock game model."""
import random
import unittest

from recovered_rules import hp_max, mp_max, level_up_bonus_points


class RecoveredRuleTests(unittest.TestCase):
    def test_hp_translation_matches_instruction_arithmetic(self):
        # MUL stores the high 32 product bits in EDX; SHR EDX,3 follows.
        # Compare independently translated instruction operations to divisions.
        rng = random.Random(382000)
        inputs = list(range(20_001)) + [rng.randrange(2**32) for _ in range(10_000)]
        for power in inputs:
            a = ((power * 0x88888889) >> 32) >> 3
            b = ((power * 0xCCCCCCCD) >> 32) >> 3
            instruction_result = ((a * b) + 50) & 0xFFFFFFFF
            self.assertEqual(hp_max(power), instruction_result, power)

    def test_mp_boundaries(self):
        self.assertEqual(mp_max(0), 50)
        self.assertEqual(mp_max(15), 51)
        self.assertEqual(mp_max(30), 56)
        self.assertEqual(mp_max(20_000), 2_666_050)
        self.assertEqual(mp_max(20_001), 2_667_323)
        for spirit in [20_001, 30_000, 2**31, 2**32 - 1]:
            # SHL 4; ADD stat; SHL 4; LEA +stat-intercept, all uint32.
            eax = (spirit << 4) & 0xFFFFFFFF
            eax = (eax + spirit) & 0xFFFFFFFF
            eax = (eax << 4) & 0xFFFFFFFF
            self.assertEqual(mp_max(spirit), (eax + spirit - 0x2A9DF6) & 0xFFFFFFFF)

    def test_level_bonus_milestones(self):
        for new_level in [1, 2, 99, 101, 999]:
            self.assertEqual(level_up_bonus_points(new_level), 2)
        for new_level in [100, 200, 1000]:
            self.assertEqual(level_up_bonus_points(new_level), 3)

    def test_reject_values_outside_original_integer_domain(self):
        for value in [-1, 2**32, 1.5, True]:
            with self.assertRaises(ValueError):
                hp_max(value)
            with self.assertRaises(ValueError):
                mp_max(value)


if __name__ == "__main__":
    unittest.main()
