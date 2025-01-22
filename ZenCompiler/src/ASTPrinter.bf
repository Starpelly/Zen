using System;

using Zen.Lexer;
using Zen.Parser;

namespace Zen;

public class ASTPrinter
{
	public void PrintExpr(String outStr, Expr expr)
	{
		let type = expr.GetType();
		switch (type)
		{
		case .Binary:
			VisitAssignExpr(outStr, expr as Expr.Assign);
			break;
		case .Variable:
			VisitVariableExpr(outStr, expr as Expr.Variable);
			break;
		case .Call:
			VisitCallExpr(outStr, expr as Expr.Call);
			break;
		case .Logical:
			VisitLogicalExpr(outStr, expr as Expr.Logical);
			break;
		case .Literal:
			VisitLiteralExpr(outStr, expr as Expr.Literal);
			break;
		case .Unary:
			VisitUnaryExpr(outStr, expr as Expr.Unary);
			break;
		case .Get:
			VisitGetExpr(outStr, expr as Expr.Get);
			break;
		case .Set:
			VisitSetExpr(outStr, expr as Expr.Set);
			break;
		case .Grouping:
			VisitGroupingExpr(outStr, expr as Expr.Grouping);
			break;
		case .Assign:
			VisitAssignExpr(outStr, expr as Expr.Assign);
			break;
		}
	}

	public void PrintNode(String outStr, Node node)
	{
		if (node == null)
		{
			outStr.Append("NULL");
			return;
		}

		let type = node.GetType();
		switch (type)
		{
		case .Using:
			VisitUsingNode(outStr, node as Node.Using);
			break;
		case .Namespace:
			VisitNamespaceNode(outStr, node as Node.Namespace);
			break;
		case .Block:
			VisitBlockNode(outStr, node as Node.Block);
			break;
		case .Expression:
			VisitExprNode(outStr, node as Node.Expression);
			break;
		case .CEmbed:
			VisitCEmbedNode(outStr, node as Node.CEmbed);
			break;
		case .Function:
			VisitFunctionNode(outStr, node as Node.Function);
			break;
		case .Const:
			VisitConstNode(outStr, node as Node.Const);
			break;
		case .Struct:
			VisitStructNode(outStr, node as Node.Struct);
			break;
		case .Enum:
			VisitEnumNode(outStr, node as Node.Enum);
			break;
		case .Print:
			// Deprecated
			break;
		case .Return:
			VisitReturnNode(outStr, node as Node.Return);
			break;
		case .If:
			VisitIfNode(outStr, node as Node.If);
			break;
		case .While:
			VisitWhileNode(outStr, node as Node.While);
			break;
		case .Variable:
			VisitVariableNode(outStr, node as Node.Variable);
			break;
		case .EOF:
			VisitEOFNode(outStr, node as Node.EOF);
			break;
		}
	}

	public void VisitAssignExpr(String outStr, Expr.Assign expr)
	{

	}

	public void VisitBinaryExpr(String outStr, Expr.Binary expr)
	{

	}

	public void VisitCallExpr(String outStr, Expr.Call expr)
	{

	}

	public void VisitGetExpr(String outStr, Expr.Get expr)
	{

	}

	public void VisitGroupingExpr(String outStr, Expr.Grouping expr)
	{

	}

	public void VisitLiteralExpr(String outStr, Expr.Literal expr)
	{

	}

	public void VisitLogicalExpr(String outStr, Expr.Logical expr)
	{

	}

	public void VisitSetExpr(String outStr, Expr.Set expr)
	{

	}

	public void VisitUnaryExpr(String outStr, Expr.Unary expr)
	{

	}

	public void VisitVariableExpr(String outStr, Expr.Variable expr)
	{
	}

	public void VisitUsingNode(String outStr, Node.Using node)
	{
		outStr.Append(scope $"(using {node.Name.Lexeme})");
	}

	public void VisitNamespaceNode(String outStr, Node.Namespace node)
	{
		outStr.Append(scope $"(namespace {node.List.NamespaceListToString(.. scope .())})");
	}

	public void VisitBlockNode(String outStr, Node.Block node)
	{
		for (let block in node.Nodes)
		{
			PrintNode(outStr, block);
		}
	}

	public void VisitStructNode(String outStr, Node.Struct node)
	{
		let builder = scope String();
		defer outStr.Append(builder);

		builder.Append(scope $"(struct {node.Name.Lexeme}");

		builder.Append(")");
	}

	public void VisitEnumNode(String outStr, Node.Enum node)
	{

	}

	public void VisitExprNode(String outStr, Node.Expression node)
	{
		parenthesize(outStr, ";", node.InnerExpression);
	}

	public void VisitCEmbedNode(String outStr, Node.CEmbed node)
	{

	}

	public void VisitFunctionNode(String outStr, Node.Function node)
	{
		let builder = scope String();
		defer outStr.Append(builder);

		builder.Append(scope $"(fun {node.Name.Lexeme} (");

		for (let param in node.Parameters)
		{
			if (param != node.Parameters[0]) builder.Append(" ");
			builder.Append(VisitVariableNode(.. scope .(), param));
		}

		builder.Append(") ");

		for (let body in node.Body.Nodes)
		{
			builder.Append(PrintNode(.. scope .(), body));
		}

		builder.Append(")");
	}

	public void VisitConstNode(String outStr, Node.Const node)
	{

	}

	public void VisitIfNode(String outStr, Node.If node)
	{

	}

	public void VisitReturnNode(String outStr, Node.Return node)
	{
		if (node.Value == null)
		{
			outStr.Append("(return)");
			return;
		}
		parenthesize(outStr, "return", node.Value);
	}

	public void VisitWhileNode(String outStr, Node.While node)
	{

	}

	public void VisitVariableNode(String outStr, Node.Variable node)
	{
		if (node.Initializer == null)
		{
			parenthesize(outStr, "var", node.Type, node.Name);
			return;
		}

		parenthesize(outStr, "var", node.Name, "=", node.Initializer);
	}

	public void VisitEOFNode(String outStr, Node.EOF node)
	{
		outStr.Append("EOF");
	}

	private void parenthesize(String outStr, StringView name, params Object[] parts)
	{
		let builder = scope String();
		defer outStr.Append(builder);

		builder.Append("(");
		builder.Append(name);

		for (let part in parts)
		{
			builder.Append(" ");

			// Check base types first (Nodes and Exprs)
			let baseType = part.GetType().BaseType;
			if (baseType == typeof(Expr))
			{
				builder.Append(PrintExpr(.. scope .(), part as Expr));
				continue;
			}
			if (baseType == typeof(Node))
			{
				builder.Append(PrintNode(.. scope .(), part as Node));
				continue;
			}

			// Normal type checking
			switch (part.GetType())
			{
			case typeof(NonPrimitiveDataType):
				let type = (NonPrimitiveDataType)part;
				let namespaces = type.Namespace.NamespaceListToString(.. scope .());
				if (!namespaces.IsEmpty)
					namespaces.Append("::");

				builder.Append(scope $"{namespaces}{type.Name}");
				break;
			case typeof(Token):
				builder.Append(((Token)part).Lexeme);
				break;
			default:
				builder.Append(part.ToString(.. scope .()));
				break;
			}
		}

		builder.Append(")");
	}

	private void parenthesizeExprs(String outStr, StringView name, params Expr[] exprs)
	{
		let builder = scope String();
		defer outStr.Append(builder);

		builder.Append("(");
		builder.Append(name);

		for (let expr in exprs)
		{
			builder.Append(" ");
			builder.Append(PrintExpr(.. scope .(), expr));
		}

		builder.Append(")");
	}
}