using System;
using System.Xml;
using Nota.Vendor;

namespace Nota.Verification;

/// <summary>
/// Two deliberate faults, both asserted by verify.sh.
///
/// The using directives are in the right order and have no blank line between the blocks, which
/// UA1001 reports. SA1516 used to report that, but only because
/// dotnet_separate_import_directive_groups was set - and setting that key at any value arms the
/// organize-imports stage of "dotnet format style", which sorts first party above the vendors and
/// leaves "dotnet format --verify-no-changes" failing forever. The key is gone; UA1001 makes the
/// check now, and knows first party from vendor where SA1516 only ever saw first-level namespaces.
///
/// The two members below have no blank line between them either. That is SA1516's own job and
/// nothing to do with usings, so it stays asserted here rather than leaving with the key. They carry
/// no documentation comments on purpose: a comment between them would be reported by SA1514 instead,
/// and SA1600 is off here, so their absence costs nothing.
/// </summary>
public static class Unseparated
{
    public static string First => typeof(Thing).Name;
    public static string Second => typeof(XmlDocument).Name + Environment.NewLine;
}
